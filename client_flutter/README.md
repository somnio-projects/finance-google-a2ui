# FinanceA2Ui — Flutter client

Flutter client for the crypto market agent, rendering agent-driven A2UI
surfaces. The agent lives in [`backend_python/`](../backend_python/README.md).

## TL;DR: Run this example

1. Start the agent:

   ```bash
   cd ../backend_python && uv run .
   ```

2. Run the client, pointing it at the agent:

   ```bash
   cd app && flutter run -d chrome \
     --dart-define=BACKEND_BASE_URL=http://localhost:10002
   ```

`BACKEND_BASE_URL` is optional in local development — it defaults to
`http://localhost:10002`. A value that is not an absolute `http(s)` URL
fails at startup naming the key, rather than silently falling back.

## Layout

| Path | What it is |
| --- | --- |
| `app/` | The Flutter application (`finance_a2ui_client`) |
| `app/lib/src/config/` | `AppConfig` — the only place a backend URL literal may live |
| `app/lib/src/theme/` | `FinanceTokens` + `AppTheme` — the only place colour literals may live |
| `app/lib/src/features/` | Feature-first UI (bloc + view + repository) |
| `e2e_test/` | End-to-end tests against a live agent; needs `GEMINI_API_KEY` |
| `tool/` | `check_tokens.sh` / `check_config.sh` — the two grep gates |

## Checks

```bash
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
(cd app && flutter test)
(cd app && flutter build web --release)
./tool/check_tokens.sh
./tool/check_config.sh
```

## Toolchain

Pinned in [`.fvmrc`](.fvmrc). FVM is not required — the pin records the
Flutter version this workspace is verified against.
