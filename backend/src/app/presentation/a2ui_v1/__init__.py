"""The A2UI v1.0 wire, beside v0.9 and never instead of it (ADR-M).

Everything in this package is pure, like the rest of the presentation layer:
it turns the projection registry into the generated v1.0 catalog and turns
rendered payloads into v1.0 messages. It never renders a projection itself and
never reads a portfolio — the services hand it payloads that the same
``ViewService`` already rendered for ``GET /v1/portfolios/current/views``, so
the two wires cannot disagree about a figure (ADR-K, ADR-M D-3).

Nothing on the v0.9 path imports this package.
"""
