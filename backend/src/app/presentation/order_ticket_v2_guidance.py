"""What the model is taught about ``order.ticket.v2`` (spec 0031).

Design-owned prose, from the Zone 3 fragment of `Catalog_OrderTicket.dc.html`
— the page whose A2UI schema block is the multi-leg ticket this projection
serves. Three edits from the designer's wording, each recorded here and in
spec 0031 §3 (OD-6):

* *"let the client recompute impact on edit"* is **not transcribed**. Spec
  0024 §5 declined the whole fragment for this sentence: it instructs the
  reader to compute a figure, which is the numbers-from-tools invariant
  broken in the one place designed to teach the model the rules. The impact
  is recomputed **here**, on every re-render; the sentence now says so.
* *"the user submits via onSubmit; execution is simulated by the backend"*
  names an event and a capability this showcase does not have (spec 0018
  OD-2). The fragment keeps the designer's rule — never place or confirm an
  order in prose — and drops the mechanism it cannot honour.
* The example intent is kept verbatim: it is the design's own Flow C prompt
  and the one the `draft_order` tool exists to answer.
"""

from typing import Final

from app.presentation.guidance import Guidance

GUIDANCE: Final[Guidance] = Guidance(
    use_when=(
        "the user expresses buy or sell INTENT that resolves to a concrete, "
        'editable order — including vague intent such as "put ~$10k into '
        'semis, keep it diversified". Propose legs through `draft_order`; '
        "the impact (weights, cash, shares) is always shown so the "
        "consequences are visible before anything is confirmed, and the "
        "backend recomputes it on every edit."
    ),
    avoid_when=(
        "placing or confirming an order in prose — nothing here executes, and "
        "the ticket says so. A single asset with no impact panel is "
        "`order.ticket.v1`; what a proposed sale realises under each lot "
        "method is `scenario.comparison.v1`. Never recompute a figure the "
        "payload already carries."
    ),
)

__all__ = ["GUIDANCE"]
