# 0030 — The greeting names the caller

- **Area:** backend (+ frontend/0012 for the rail)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [0026](0026-the-home-shell.md) OD-1 (the persona), [0027](0027-user-provisioning.md) (the users registry), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) N-9
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

The Home header greets **Alex Chen** whoever signs in. 0026 OD-1 made the
persona seed data because a `jwt` token's `sub` is `alice` — a scoping
subject, not a name — and nothing else was known about the caller. Since
0027 the service knows more: the users registry carries a `display_name`, and
an OIDC token (Firebase, which dev runs) carries an e-mail. Greeting a signed-in
reviewer as *Alex Chen* is the demo contradicting its own login.

`payoff.curve.v1` still opens on `VOO` when nobody names a symbol. Flow C's
NVDA/AVGO/AMD order is the *agent's* choice, carried in the render intent's
`symbol`; moving the default would have meant rewriting nine hand-verified
payoff oracles for a page only the catalog index reaches. Left as is, on
purpose, and recorded so it is not mistaken for an oversight.

## 2. What ships

- **`Portfolio.owner`**, a `PortfolioOwner(name, initial)` the *service*
  sets before rendering — the projection stays pure and reads it like any
  other fact about the portfolio. `owner_from(display_name, email)` picks the
  registry's display name, then the e-mail's local part with its first letter
  raised; with neither it answers `None` and the shell keeps the persona.
- `ViewService` takes an optional `OwnerResolver`; the composition root
  passes `UserService`, whose `owner_for(principal)` reads the registry once.
  The A2A path renders through the same service, so a surface the agent asks
  for greets the same person.
- `portfolio.summary.v1` binds `account` from the owner when there is one.
  The `Simulated portfolio` badge is unchanged: it is a compliance statement,
  not a name (0026 OD-1).

## 3. Rulings

- **OD-1 — the server spells the name.** Raising the first letter of an
  e-mail's local part is the server's formatting; the client binds the
  string. A client that derived a monogram from an e-mail would be N-9's
  first violation.
- **OD-2 — the persona is the fallback, not a second path.** A `jwt` dev
  token with no e-mail still greets Alex Chen, so the catalog example and
  every seeded test keep their literals. Nothing is conditional in the client.
- **OD-3 — the owner is a field, not a parameter.** Threading a caller
  through `Projection.render` would change the Protocol for nine
  projections to serve one; a portfolio has an owner the way it has an
  `as_of`.

## 4. Test decision

Unit: `owner_from` over a display name, an e-mail, a name with surrounding
space, an e-mail with no local part and nothing; the view service sets the
owner from its resolver and leaves the portfolio untouched without one; the
summary greets the owner and falls back to the persona. Existing suites over
the seeded portfolio are unchanged — the seed has no owner.
