# 0002 — Firebase sign-in on dev, end to end

- **Area:** infra (with the client's build recipe and Hosting target)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [infra/0001](0001-dev-environment.md) (the dev shape), [backend/0027](../backend/0027-user-provisioning.md) (invite-only registry, `AUTH_BOOTSTRAP_ADMINS`), [backend/0033](../backend/0033-the-simulated-assistant-offline.md) (no key = the scripted assistant), [frontend/0008](../frontend/0008-sign-in.md) (Firebase is the provider; OD-8 on the Google toggle), [ADR-B](../../docs/adr/ADR-B-auth-credential-contract.md) D-10
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Everything needed for a real sign-in existed and nothing joined it. The dev
backend runs `AUTH_PROVIDER=oidc` against `securetoken.google.com/finance-a2ui`
and the client has a Firebase adapter, but:

- the Cloud Run service carried **no `AUTH_BOOTSTRAP_ADMINS`**, so its registry
  had no admin and no e-mail could ever be invited — every Firebase identity
  would have signed in and been told it was not provisioned (0027 OD-2);
- the **`GEMINI_API_KEY` secret existed with a version and was mounted
  nowhere** — `run.tf` mounted `DATABASE_URL`, `AUTH_JWT_SECRET` and
  `SENTRY_DSN` only — so the deployed assistant was the scripted one and no
  amount of deploying would have changed that;
- `CORS_ALLOWED_ORIGINS` named `localhost:8080` and nothing a browser on
  Firebase Hosting would send;
- `firebase.json` served the **older** `client_flutter` build, not the A2UI
  client this repository ships;
- the client's five public Firebase values lived in nobody's shell history.

## 2. What ships

| Where | Change |
|---|---|
| `infra/variables.tf` | `auth_bootstrap_admins` (string, default `""`) |
| `infra/run.tf` | `AUTH_BOOTSTRAP_ADMINS` in `backend_env`; `GEMINI_API_KEY` in `backend_secret_env` from the existing external secret — the per-secret accessor IAM already covers every `external` secret |
| `infra/environments/dev.tfvars` | `auth_bootstrap_admins = "lbertuzzi@somniosoftware.com"`; CORS adds `https://finance-a2ui.web.app`, `https://finance-a2ui.firebaseapp.com`, `http://localhost:5173` |
| `firebase.json` | `hosting.public` → `frontend/app/build/web` |
| `frontend/app/config/firebase.example.json` + `frontend/README.md` | the `--dart-define-from-file` recipe: one file names one environment (backend URL + the public Firebase web config); the real file is git-ignored |

## 3. Rulings

- **OD-1 — the first admin is configuration, and configuration is Terraform.**
  0027 OD-2 already ruled that a registry with no admin can never gain one
  through the API; dev had simply never been given one. The e-mail goes in
  `dev.tfvars`, not in a console, so the next environment cannot forget it.
- **OD-2 — the model key is mounted, its value is not ours.** Terraform mounts
  the secret it already declares; the version is set out of band by the
  security owner (secrets.tf, diagram 08). Until a version exists the
  container reads `""`, which `OptionalCredentialParsing` collapses to `None`
  and the scripted assistant answers (0033 OD-4) — the same code path as a
  laptop with no key, so the demo degrades honestly rather than failing.
- **OD-3 — the public web config is not a secret, and still not committed.**
  ADR-B D-10 classifies the Firebase browser key as public; gitleaks does not
  read ADRs and flags any `AIza…` literal, and a reviewer cannot tell a public
  key from a leaked one by looking. The example file carries every value but
  the key, with the console path to it, and the real file is ignored.
- **OD-4 — Google at the IdP stays a console toggle.** Firebase's admin API
  still refuses to enable the Google provider without an OAuth client id
  (0008 OD-8); `defaultSupportedIdpConfigs` on the project is empty today. A
  build with the config therefore answers *operation-not-allowed* on the
  Google button until someone presses **Enable** once. The e-mail link works
  without it.
- **OD-5 — Hosting serves the client this repository is about.** `firebase.json`
  pointed at `client_flutter`; the two apps share no code (CLAUDE.md) and the
  A2UI client is the one every spec since frontend/0001 describes.

## 4. Acceptance

- `terraform validate` and the infra suite (`test_dev_environment`,
  `test_rate_limit_ceiling`, `test_wif_conditions`) green; `terraform plan`
  on dev shows the two env changes and one secret mount, nothing else.
- After `apply` + a `backend-cd` run of `develop`: `GET /v1/me/access` with a
  Firebase ID token for the bootstrap admin answers `provisioned: true`.
- A web build with the dev config, served from Hosting, signs in with the
  e-mail link; with Google once the provider is enabled.

Not done here: the `apply` and the deploy — both are a human's button by
the repository's rules (CLAUDE.md § Conventions; GGU-29).
