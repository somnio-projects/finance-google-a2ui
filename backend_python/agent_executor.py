# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import logging
import math
import os

from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.tasks import TaskUpdater
from a2a.types import (
    DataPart,
    Part,
    Task,
    TaskState,
    TextPart,
    UnsupportedOperationError,
)
from a2a.utils import (
    new_agent_parts_message,
    new_agent_text_message,
    new_task,
)
from a2a.utils.errors import ServerError
from a2ui.a2a.extension import try_activate_a2ui_extension
from agent import CryptoAgent
from tools import find_asset, format_quantity, format_usd

logger = logging.getLogger(__name__)

DEFAULT_ORDER_HINT = "Enter the amount in USD you want to spend."


def _parse_amount_usd(raw) -> float | None:
    try:
        amount = float(str(raw).replace("$", "").replace(",", "").strip())
    except ValueError:
        return None
    return amount if math.isfinite(amount) and amount > 0 else None


def _buy_query(asset: dict, hint: str) -> str:
    return (
        f"USER_WANTS_TO_BUY: {asset['name']}, Symbol: {asset['symbol']},"
        f" PriceDisplay: {asset['priceDisplay']}, LogoURL: {asset['logoUrl']},"
        f" Hint: {hint}"
    )


class CryptoAgentExecutor(AgentExecutor):
    """Crypto market AgentExecutor."""

    def __init__(self, agent: CryptoAgent):
        self._agent = agent

    async def execute(
        self,
        context: RequestContext,
        event_queue: EventQueue,
    ) -> None:
        query = ""
        ui_event_part = None
        action = None
        order_placed = False

        logger.info(
            f"--- Client requested extensions: {context.requested_extensions} ---"
        )
        active_ui_version = try_activate_a2ui_extension(context, self._agent.agent_card)

        # Determine which agent to use based on whether the a2ui extension is active.
        if active_ui_version:
            logger.info(
                "--- AGENT_EXECUTOR: A2UI extension is active. Using UI agent. ---"
            )
        else:
            logger.info(
                "--- AGENT_EXECUTOR: A2UI extension is not active. Using text"
                " agent. ---"
            )

        use_streaming = os.getenv("USE_STREAMING", "true").lower() != "false"
        if context.message and context.message.parts:
            logger.info(
                f"--- AGENT_EXECUTOR: Processing {len(context.message.parts)} message"
                " parts ---"
            )
            for i, part in enumerate(context.message.parts):
                if isinstance(part.root, DataPart):
                    if "useStreaming" in part.root.data:
                        use_streaming = part.root.data["useStreaming"]
                        logger.info(f"  Part {i}: Found useStreaming={use_streaming}")

                    if (
                        part.root.data.get("version") == "v0.9"
                        and "action" in part.root.data
                    ):
                        logger.info(f"  Part {i}: Found a2ui v0.9 action payload.")
                        ui_event_part = part.root.data["action"]
                    elif "userAction" in part.root.data:
                        logger.info(
                            f"  Part {i}: Found a2ui v0.8 UI ClientEvent payload."
                        )
                        ui_event_part = part.root.data["userAction"]
                    else:
                        logger.info(f"  Part {i}: DataPart (data: {part.root.data})")
                elif isinstance(part.root, TextPart):
                    logger.info(f"  Part {i}: TextPart (text: {part.root.text})")
                else:
                    logger.info(f"  Part {i}: Unknown part type ({type(part.root)})")

        if ui_event_part:
            logger.info(f"Received a2ui ClientEvent: {ui_event_part}")
            action = ui_event_part.get("name")
            ctx = ui_event_part.get("context", {})

            # Prices and quantities come from the data file and are computed here,
            # so the LLM only copies numbers and never does the math.
            if action in ("buy_asset", "submit_order"):
                symbol = str(ctx.get("symbol", ""))
                asset = find_asset(symbol, self._agent.base_url)

                if asset is None:
                    query = f"User tried to {action} an unknown asset: '{symbol}'."
                elif action == "buy_asset":
                    query = _buy_query(asset, DEFAULT_ORDER_HINT)
                else:
                    raw_amount = ctx.get("amountUsd", "")
                    amount = _parse_amount_usd(raw_amount)
                    if amount is None:
                        query = _buy_query(
                            asset,
                            f"'{raw_amount}' is not a valid amount. Enter a positive"
                            " amount in USD.",
                        )
                    else:
                        order_placed = True
                        quantity = format_quantity(amount / asset["price"])
                        query = (
                            f"User submitted an order: {asset['name']},"
                            f" Symbol: {asset['symbol']},"
                            f" AmountDisplay: {format_usd(amount)},"
                            f" PriceDisplay: {asset['priceDisplay']},"
                            f" Quantity: {quantity}, LogoURL: {asset['logoUrl']}"
                        )

            else:
                query = f"User submitted an event: {action} with data: {ctx}"
        else:
            logger.info("No a2ui UI event part found. Falling back to text input.")
            query = context.get_user_input()

        logger.info(f"--- AGENT_EXECUTOR: Final query for LLM: '{query}' ---")

        task = context.current_task

        if not task:
            task = new_task(context.message)
            await event_queue.enqueue_event(task)
        updater = TaskUpdater(event_queue, task.id, task.context_id)

        async for item in self._agent.stream(
            query, task.context_id, active_ui_version, use_streaming=use_streaming
        ):
            is_task_complete = item["is_task_complete"]
            if not is_task_complete:
                message = None
                if "parts" in item:
                    message = new_agent_parts_message(
                        item["parts"], task.context_id, task.id
                    )
                elif "updates" in item:
                    message = new_agent_text_message(
                        item["updates"], task.context_id, task.id
                    )

                if message:
                    await updater.update_status(TaskState.working, message)
                continue

            final_state = (
                TaskState.completed if order_placed else TaskState.input_required
            )

            final_parts = item["parts"]

            logger.info("--- FINAL PARTS TO BE SENT ---")
            for i, part in enumerate(final_parts):
                logger.info(f"  - Part {i}: Type = {type(part.root)}")
                if isinstance(part.root, TextPart):
                    logger.info(f"    - Text: {part.root.text[:200]}...")
                elif isinstance(part.root, DataPart):
                    logger.info(f"    - Data: {str(part.root.data)[:200]}...")
            logger.info("-----------------------------")

            await updater.update_status(
                final_state,
                new_agent_parts_message(final_parts, task.context_id, task.id),
                final=(final_state == TaskState.completed),
            )
            break

    async def cancel(
        self, request: RequestContext, event_queue: EventQueue
    ) -> Task | None:
        raise ServerError(error=UnsupportedOperationError())
