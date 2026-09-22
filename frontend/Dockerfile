# syntax=docker/dockerfile:1.7
#
# The A2UI finance client (`frontend/`), built once and served as static files.
#
# Shape mirrors backend/Dockerfile and client_flutter/Dockerfile: a builder
# stage carrying the whole toolchain, a runtime stage carrying nothing but what
# is served, both pinned by digest, non-root, read-only root filesystem
# (enforced by docker-compose.yml), no-new-privileges, health check.
#
# Two of its decisions differ from client_flutter's, and both are deliberate.
#
# ---------------------------------------------------------------------------
# Decision 1 — configuration is COMPILED IN, and this image is per-environment.
# ---------------------------------------------------------------------------
# client_flutter/Dockerfile argues the opposite (its Decision 1): render
# /config.json at container start so one image is promotable by digest, the way
# the backend's is. That argument is correct *for a container that is the
# deployable*. It does not hold here, because this app's deployable is not a
# container at all — `frontend-cd.yaml` publishes a static bundle to Firebase
# Hosting, and Hosting has no process to render anything at start. A bundle is
# built against exactly one environment or it is built against none.
#
# The seam agrees. `app/lib/app/app_config.dart` reads `String.fromEnvironment`
# and `app/test/architecture/layering_test.dart` fails ANY other one, so a
# runtime loader is not a flag away: it is a second config path through a
# layer that deliberately has one. Adding it to serve a container that is not
# the deployable would buy image identity at the cost of the rule that keeps
# configuration readable in a single place.
#
# What that costs, said plainly rather than left implicit: the image CI builds
# for dev is not byte-identical to one built for production, so "promote the
# digest" is not available to this app. The mitigation is that the digest is
# not what production consumes either — Hosting consumes a bundle, and
# `frontend-cd.yaml` verifies the bundle it deployed by fetching /release.json
# from the live site and comparing it to the commit it built. Verification
# after the fact replaces identity before it.
#
# The build args below therefore carry ONE environment's public configuration.
# None of them is a credential: the Firebase web config is public by design
# (ADR-B D-10) and reaches every browser in the bundle regardless.
#
# ---------------------------------------------------------------------------
# Decision 2 — the CSP admits www.gstatic.com, and COOP allows popups.
# ---------------------------------------------------------------------------
# This client signs in through Firebase, which client_flutter does not, and
# both facts follow from that:
#
#   - `firebase_core_web` injects `https://www.gstatic.com/firebasejs/<v>/…`
#     script tags at run time. Measured on the committed bundle: three
#     references to gstatic.com in main.dart.js. Under client_flutter's
#     `script-src 'self'` the page loads and sign-in dies at the first Firebase
#     call, so `script-src` names that host and `connect-src` names the two
#     identity endpoints the SDK talks to.
#   - `Cross-Origin-Opener-Policy: same-origin` severs `window.opener` between
#     the page and the sign-in popup, which is exactly the handle
#     `signInWithPopup` resolves its promise on. The value here is
#     `same-origin-allow-popups`: it keeps cross-origin documents from
#     reaching into this one, and keeps the popup this page opened itself.
#
# Everything else in docker/nginx.conf.template is the client's header set,
# unchanged, because nothing about this app weakens the reasoning behind it.
#
# ---------------------------------------------------------------------------
# Decision 3 — the SDK version is READ from .fvmrc, never written here.
# ---------------------------------------------------------------------------
# `frontend/.fvmrc` is the one home for this app's Flutter version (GGU-94) and
# `scripts/check_gate_pairs.sh` fails a second one. An `ARG FLUTTER_VERSION=…`
# would be that second home, one file over — the defect that check exists to
# catch, restated in a Dockerfile where it does not look for it. So the version
# is read from the file at build time.
#
# A checksum cannot be derived that way, so `docker/flutter-sdk-checksums.json`
# maps version → SHA-256 as Google publishes it in releases_linux.json. That is
# a lookup table keyed by the pin, not a second pin: bump `.fvmrc` without
# adding the row and the build stops and says which row to add, rather than
# downloading an unverified tarball.

# ---------------------------------------------------------------------------
# One environment's public configuration, declared BEFORE the first FROM so it
# is in global scope and both stages can redeclare and read it. None of these
# is a credential: the Firebase web config is public by design (ADR-B D-10)
# and reaches every browser inside the bundle regardless.
#
# The defaults are the local stack: the backend on :8000 as the BROWSER sees
# it, and no Firebase at all. An empty FIREBASE_API_KEY is not a degraded
# build, it is a declared state — `AppConfig.fromEnvironment` returns a null
# `firebase`, the Google button says it is not configured instead of failing
# at the first click, and the e-mail path is answered by the backend's preview
# sign-in (spec backend/0027 OD-3). The local stack has no Firebase project,
# so this is the honest shape for it.
ARG BACKEND_BASE_URL=http://localhost:8000
ARG FIREBASE_API_KEY=
ARG FIREBASE_APP_ID=
ARG FIREBASE_PROJECT_ID=
ARG FIREBASE_AUTH_DOMAIN=
ARG FIREBASE_MESSAGING_SENDER_ID=

# Which build this is, in the backend's `<version>+<short sha>` shape
# (GGU-93). It is served at /release.json and is the only thing that says
# which commit produced the bundle a browser is running — the same question
# `/health` answers for the API, and the same reason it is never cached.
# `local` is what you get for forgetting it, which the check rejects rather
# than accepting as an identity.
ARG APP_RELEASE=local

# The Flutter SDK ships for linux/amd64 only, so the builder is pinned to it.
# The runtime stage is free to follow the target platform: `flutter build web`
# emits JavaScript, wasm and assets, none of which are architecture-specific.
FROM --platform=linux/amd64 debian:12-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251 AS builder

# Base-layer security updates, then exactly what the SDK needs to unpack and
# run: git (the SDK is a git checkout and refuses to run without it), xz/unzip
# for the archives, curl and CA roots for the download, jq to read the pin.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git jq unzip xz-utils \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Decision 3. Copied on their own so that editing Dart source does not
# re-download the SDK.
COPY .fvmrc ./
COPY docker/flutter-sdk-checksums.json ./docker/

RUN set -eu; \
    version="$(jq -r .flutter .fvmrc)"; \
    sha="$(jq -r --arg v "$version" '.[$v] // empty' docker/flutter-sdk-checksums.json)"; \
    if [ -z "$sha" ]; then \
      echo "Dockerfile: .fvmrc pins Flutter ${version}, and docker/flutter-sdk-checksums.json has no checksum for it." >&2; \
      echo "Dockerfile: add the sha256 for that release from" >&2; \
      echo "Dockerfile:   https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json" >&2; \
      echo "Dockerfile: the build refuses to fetch an SDK it cannot verify." >&2; \
      exit 1; \
    fi; \
    curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${version}-stable.tar.xz"; \
    echo "${sha}  /tmp/flutter.tar.xz" | sha256sum -c -; \
    tar -xf /tmp/flutter.tar.xz -C /opt; \
    rm /tmp/flutter.tar.xz; \
    git config --global --add safe.directory /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Off by default in a container, but say so rather than rely on it: a build
# must not phone home, and `flutter --version` warms the tool cache so the
# first real command is not also a download.
RUN flutter config --no-analytics >/dev/null \
 && flutter --version

# Resolve from the manifests alone, so editing Dart source does not re-run pub.
# `workspace:` in the root pubspec means pub resolves the whole tree at once,
# so every member's manifest has to be present before `pub get` runs.
#
# --enforce-lockfile: resolve to exactly what pubspec.lock pins, or fail. Plain
# `pub get` silently re-resolves, and a container that quietly builds a
# different dependency set than the one the gate proved is worse than one that
# stops. It is the same flag `frontend/Makefile` uses for the same reason.
COPY pubspec.yaml pubspec.lock ./
COPY app/pubspec.yaml ./app/
COPY packages/finance_core/pubspec.yaml ./packages/finance_core/
COPY packages/finance_api_client/pubspec.yaml ./packages/finance_api_client/
COPY packages/finance_views_repository/pubspec.yaml ./packages/finance_views_repository/
COPY packages/finance_auth/pubspec.yaml ./packages/finance_auth/
COPY packages/finance_charts/pubspec.yaml ./packages/finance_charts/
RUN flutter pub get --enforce-lockfile

COPY . .

# Decision 1 — one environment's public configuration, and nothing secret.
# Bare `ARG` re-declarations: the values and their defaults are in global
# scope above, so they cannot drift between the two stages that read them.
ARG BACKEND_BASE_URL
ARG FIREBASE_API_KEY
ARG FIREBASE_APP_ID
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_AUTH_DOMAIN
ARG FIREBASE_MESSAGING_SENDER_ID
ARG APP_RELEASE

# The build flags are NOT here. `tool/build_web.sh` owns them, and
# `frontend-cd.yaml` calls the same script, so the container is compiled by
# the same command as the bundle that reaches Hosting. Two flag lists is the
# drift §5 of ci-conventions.md is about, in a place its machine check cannot
# look: neither half is a ship-gate command, so nothing would have compared
# them.
#
# The script also writes /release.json, which is why it needs APP_RELEASE.
RUN BACKEND_BASE_URL="${BACKEND_BASE_URL}" \
    APP_RELEASE="${APP_RELEASE}" \
    FIREBASE_API_KEY="${FIREBASE_API_KEY}" \
    FIREBASE_APP_ID="${FIREBASE_APP_ID}" \
    FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID}" \
    FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN}" \
    FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID}" \
    bash tool/build_web.sh

# ---------------------------------------------------------------------------

FROM nginxinc/nginx-unprivileged:1.27-alpine-slim@sha256:ec6b8b1f1bfa594db13e99fc692b9fb816cb7e365927196610f622659de95913 AS runtime

# Pull Alpine security updates so the image does not ship base-layer CVEs — the
# same reason backend/Dockerfile runs apt-get upgrade. Root is needed for apk
# and is given straight back; 101 is this image's own unprivileged nginx user.
USER root
RUN apk --no-cache upgrade
USER 101

# Redeclared from global scope. The entrypoint renders the CSP from these, so
# the policy names exactly the origins the bundle above was compiled to call
# — one build argument, two consumers, no second place to keep in step.
ARG BACKEND_BASE_URL
ARG FIREBASE_AUTH_DOMAIN

ENV PORT=8080 \
    APP_BACKEND_ORIGIN=${BACKEND_BASE_URL} \
    APP_FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN}

WORKDIR /usr/share/nginx/html

# Nothing from the builder but the bundle: no SDK, no pub cache, no Dart source.
COPY --from=builder --chown=101:101 /src/app/build/web/ ./
COPY --chown=101:101 docker/nginx.conf.template /etc/nginx/nginx.conf.template
COPY --chown=101:101 docker/entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 8080

# /health, not /healthz: Google's edge intercepts the exact path /healthz on
# *.run.app and answers it before it reaches the container, so a probe on it
# proves nothing (harness log, 2026-09-20). Shell form so ${PORT} expands at
# run time.
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null "http://127.0.0.1:${PORT}/health" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
