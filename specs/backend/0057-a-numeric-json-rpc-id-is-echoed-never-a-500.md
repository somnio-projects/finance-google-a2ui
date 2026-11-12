# 0057 — A numeric JSON-RPC id is accepted and echoed, never a 500

- **Area:** backend
- **Status:** In progress
- **Ticket:** [GGU-164](https://somniosoftware.atlassian.net/browse/GGU-164)
- **Related:** [0010](0010-a2a-surface.md) (the A2A envelope), [0053](0053-the-agent-speaks-a2ui-v1.md) (the v1.0 wire shares the envelope)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-11-12

## 1. Problem

JSON-RPC 2.0 allows `id` to be a string, a number or null. `JsonRpcRequest.id`
was `str | int | None` with `max_length=128` on the field. Pydantic applies
that constraint to every branch of the union, and for an integer it raises
`TypeError: Unable to apply constraint 'max_length'` — not a `ValidationError`.
`dispatch.parse` only catches `ValidationError`, so `POST /` with `"id": 1`
answered **HTTP 500**. `POST /a2ui/v1/a2a` shares the same envelope and failed
the same way.

## 2. Scope

**In:** the `RpcId` type in `schemas/a2a.py`, declared per branch, used by the
request envelope, `JsonRpcFailure` and the services that echo an id.
**Out:** the success stream carries no JSON-RPC id (events are A2A task
events); unchanged.

## 3. API contract

No new route. `id` is: a string of at most 128 characters, an integer in
`[-(2**53-1), 2**53-1]` (the JSON-safe range), or null/absent. Booleans, floats,
arrays and objects are refused. A refused envelope answers HTTP 200 with a
JSON-RPC error `-32602` and `id: null` (existing behaviour for a malformed
envelope). A valid id is echoed in failures with the same JSON type. OpenAPI:
the request schema now documents the three branches.

## 4. Data model & migration

None.

## 5. Security notes

The bound exists because the id is reflected verbatim; both bounds keep a
response from growing with caller input. `StrictInt` stops `true` coercing to
`1`. No new log fields.

## 6. Acceptance criteria

1. **AC-1** — a numeric id is accepted and echoed as a number on `POST /` and `POST /a2ui/v1/a2a`.
2. **AC-2** — a string id over 128 characters, an integer outside the JSON-safe range and a boolean are refused as a JSON-RPC `-32602` error, never a 500.
3. **AC-3** — string, null and absent ids keep working unchanged.

## 7. Test plan

| AC | Unit | Integration |
|---|---|---|
| AC-1 | `tests/unit/schemas/test_jsonrpc_id.py`, `tests/unit/api/test_a2a_rpc_id.py::test_the_id_is_echoed_with_the_type_it_was_sent_in` | `tests/integration/test_jsonrpc_id_flow.py::test_a_numeric_id_is_echoed_as_a_number` |
| AC-2 | `test_an_invalid_id_is_a_validation_error_never_a_type_error`, `test_an_id_out_of_bounds_is_a_json_rpc_error_never_a_500` | `test_an_out_of_bounds_id_is_refused_in_the_envelope` |
| AC-3 | the string/null cases above | — |

Mutation check: restoring the old `max_length` on the union fails 20 of the 34
new unit tests.

## 8. Open decisions

None.

## 9. Rollout & observability

No flag. Behaviour change only for requests that previously returned 500.
