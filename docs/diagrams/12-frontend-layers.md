# 12 — Frontend layers

**Question:** in the `frontend/` client, what may import what, and where does a
payload go between the socket and the screen?
**Source of truth:** [ADR-L](../adr/ADR-L-client-architecture.md),
`.claude/rules/frontend/architecture.md`, and
`frontend/app/test/architecture/layering_test.dart` — which is what keeps this
picture true rather than aspirational.

```mermaid
graph TD
  subgraph app["app — Flutter (package finance_app)"]
    main["main.dart<br/>runApp(bootstrap())"]
    boot["bootstrap.dart<br/><b>the only composition root</b>"]
    router["router/app_router.dart<br/>go_router + the one auth redirect"]
    view["features/*/view<br/>widgets"]
    bloc["features/*/bloc<br/>Bloc"]
    host["components/component_host.dart<br/>+ component_registry.dart"]
    comp["components/&lt;name&gt;/<br/>one directory per view id"]
    manifest["components/component_manifest.g.dart<br/><i>generated · gated by diff</i>"]
  end

  subgraph pure["packages — pure Dart, cannot import Flutter"]
    repo["finance_views_repository<br/>envelope · ViewPayload · ETag cache"]
    api["finance_api_client<br/><b>the only HTTP speaker</b>"]
    core["finance_core<br/>Result · AppFailure · ProblemDetails"]
  end

  backend[["backend<br/>GET /v1/portfolios/{id}/views"]]

  main --> boot
  boot --> router
  boot -.->|"constructs everything:<br/>http.Client, FinanceApiClient,<br/>ViewsRepository, registry"| repo
  boot --> manifest
  manifest -->|"register()"| host
  router --> view
  view --> bloc
  view --> host
  host --> comp
  bloc --> repo
  repo --> api
  api -->|"Bearer · repeated ?view= · If-None-Match"| backend
  repo --> core
  api --> core
  comp --> repo

  %% Everything below this line is checked by layering_test.dart, not by review.
  %% FORBIDDEN, each with its own test:
  %%   bloc  -> api      (a bloc may not know HTTP exists)
  %%   comp  -> features (a component that needs a bloc is a feature)
  %%   pure/ -> flutter  (also a compile error — that is the point of the workspace)
  %%   anything but boot constructing http.Client / FinanceApiClient / ViewsRepository
  %%   NumberFormat · intl · dart:math · toStringAsFixed · double.parse · DateTime.now()
```

## Reading it

- **Dependencies point one way**: `view → bloc → repository → api client → core`. Nothing skips a layer and nothing points back up.
- **`comp → repo`** is the one edge that looks like a shortcut and is not: a component imports `ViewPayload` — a *type*, from the repository layer — and never a repository instance. It has no `bloc` and no transport.
- **`boot -.-> repo`** is dashed because it is construction, not a call. `bootstrap.dart` is the only file allowed to draw it; `layering_test.dart` fails if any other does.
- **The generated manifest is the seam.** Adding a component adds a directory and regenerates `component_manifest.g.dart`; no hand-written file in this diagram changes (ADR-L D-3, mirroring ADR-K D-15).
- **Nothing is deployed.** There is no pipeline shipping this bundle yet — `specs/client/0002-client-delivery.md` owns that — so no edge crosses into Google Cloud here. See [02-containers](02-containers.md) for where it will attach.
