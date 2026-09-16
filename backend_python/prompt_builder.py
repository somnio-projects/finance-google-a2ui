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

from a2ui.schema.constants import VERSION_0_9
from a2ui.inference_formats.direct_json import DirectJsonFormat
from a2ui.basic_catalog.provider import BasicCatalog
from a2ui.schema.common_modifiers import remove_strict_validation

ROLE_DESCRIPTION = (
    "You are a helpful crypto market assistant in a demo investing app. All market"
    " data is fake demo data and all orders are simulated. Never give investment"
    " advice. Your final output MUST be an A2UI UI definition."
)

UI_DESCRIPTION = """
-   If the query is for a list of cryptocurrencies, use the asset data you have already received from the `get_crypto_assets` tool to populate the `updateDataModel` message.
-   IMPORTANT: Copy every asset exactly as received from the tool. NEVER change, recompute, round or reformat prices, percentages or any other value.
-   IMPORTANT: When using updateDataModel to update items, you MUST specify `path: "/items"` in `updateDataModel`, and the `value` MUST be an array of assets.
-   IMPORTANT: Always specify the path when using updateDataModel. The part message is ignored when the path is missing.
-   If the number of assets is 5 or fewer, you MUST use the `single_column_list` template.
-   If the number of assets is more than 5, you MUST use the `two_column_list` template, grouping the assets into pairs.
-   If the query is to buy an asset (e.g., "USER_WANTS_TO_BUY..."), you MUST use the `order_form` template, filled with the values from the query.
-   If the query is an order submission (e.g., "User submitted an order..."), you MUST use the `order_confirmation` template, filled with the values from the query.
"""


def get_text_prompt() -> str:
    """
    Constructs the prompt for a text-only agent.
    """
    return """
    You are a helpful crypto market assistant in a demo investing app. All market data is fake demo data and all orders are simulated. Never give investment advice. Your final output MUST be a text response.

    To generate the response, you MUST follow these rules:
    1.  **For market data:**
        a. You MUST call the `get_crypto_assets` tool. Extract the category, symbols, sorting (market_cap, gainers or losers) and a specific number (`count`) of assets from the user's query.
        b. After receiving the data, format the asset list as a clear, human-readable text response. Use the pre-formatted `*Display` values exactly as received.

    2.  **For buying an asset (when you receive a query like 'USER_WANTS_TO_BUY...'):**
        a. Respond by asking the user how much in USD they want to spend.

    3.  **For confirming an order (when you receive a query like 'User submitted an order...'):**
        a. Respond with a simple text confirmation of the order details, using the values from the query exactly.
    """


if __name__ == "__main__":
    # Example of how to use the A2UI Schema Manager to generate a system prompt
    # In your actual application, you would call this from your main agent logic.

    # You can now easily construct a prompt with the relevant examples.
    # For a different agent (e.g., a flight booker), you would pass in
    # different examples but use the same `get_ui_prompt` function.
    version = VERSION_0_9
    crypto_prompt = DirectJsonFormat(
        version,
        catalogs=[
            BasicCatalog.get_config(
                version=version,
                examples_path=f"examples/{version}",
            )
        ],
        schema_modifiers=[remove_strict_validation],
    ).generate_system_prompt(
        role_description=ROLE_DESCRIPTION,
        ui_description=UI_DESCRIPTION,
        include_schema=True,
        include_examples=True,
        validate_examples=True,
    )

    print(crypto_prompt)

    # This demonstrates how you could save the prompt to a file for inspection
    with open("generated_prompt.txt", "w") as f:
        f.write(crypto_prompt)
    print("\nGenerated prompt saved to generated_prompt.txt")
