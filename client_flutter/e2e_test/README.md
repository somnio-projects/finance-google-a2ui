# e2e test

Tests that the following entities work well together:

1. The `finance_a2ui_client` Flutter client
2. The Python crypto market agent in `backend_python/`
3. An AI model

These tests are in a separate package and run in a separate CI/CD pipeline,
because they require an API key (`GEMINI_API_KEY`).

The harness starts the agent with `uv run .` in `../../backend_python`,
relative to this package directory.
