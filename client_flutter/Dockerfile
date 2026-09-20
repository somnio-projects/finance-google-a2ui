# syntax=docker/dockerfile:1.7
#
# The Flutter web client, built once and served as static files.
#
# Shape mirrors backend/Dockerfile: a builder stage that carries the whole
# toolchain, a runtime stage that carries nothing but what is served, both
# stages pinned by digest, non-root, read-only root filesystem (enforced by
# docker-compose.yml / the Cloud Run revision), no-new-privileges, health check.
#
# ---------------------------------------------------------------------------
# Decision 1 — BACKEND_BASE_URL is read at RUNTIME, not compiled in.
# ---------------------------------------------------------------------------
# `--dart-define` turns the value into a compile-time constant, which would
# mean one image per environment. That is not a secrecy argument: the backend
# base URL is public either way — it appears in every browser's network tab the
# moment the app makes its first call, so "a value baked in is a value shipped
# to every browser" is equally true of a value fetched at runtime. The argument
# is *artifact identity*. backend-cd.yaml pushes an image by digest, deploys
# that digest with no traffic, probes it, and shifts traffic to the thing it
# just probed. A per-environment client image breaks that: the artifact CI
# verified against dev is not the artifact that reaches production, and the
# production one is only ever verified in production. One image, promoted by
# digest, keeps the client's delivery story the same as the backend's.
#
# So the server writes the value: docker/entrypoint.sh renders `/config.json`
# from $BACKEND_BASE_URL at container start and serves it `no-store`.
#
# Honest status, because a comment that overclaims is worse than none:
# `client_flutter/app/lib` does NOT fetch /config.json yet — today it holds a
# hardcoded `defaultServerUrl` (landing_repository.dart:8). The server half is
# real and curl-able now; the app half is one loader in the client's own lane
# (GGU-1, PRs #26/#30), tracked as spec 0002 AC-7 and as a gap in
# client_flutter/docs/SECURITY.md. Until it lands, BACKEND_BASE_URL_FALLBACK
# below is baked in as a `String.fromEnvironment` constant so that whichever
# half arrives first is usable on its own.
#
# ---------------------------------------------------------------------------
# Decision 2 — the CSP admits `wasm-unsafe-eval`, and NOT `unsafe-eval`.
# ---------------------------------------------------------------------------
# Measured, not assumed — see specs/client/0002-client-delivery.md OD-3 for the
# console output behind this. This app builds with the default web renderer,
# which is CanvasKit: a WebAssembly module. `script-src` therefore has to
# permit WebAssembly instantiation, and the narrow directive for exactly that
# is `'wasm-unsafe-eval'` (Chrome 97+, Firefox 102+, Safari 16.4+). It permits
# WebAssembly and nothing else — `eval()` and `new Function()` stay blocked.
#
# The broad `'unsafe-eval'` is NOT needed, because `flutter build web --csp`
# tells dart2js to stop generating code dynamically. Dropping that flag is what
# forces `'unsafe-eval'`, so the flag and the header are a pair: change one and
# the other is wrong. `style-src 'unsafe-inline'` IS required — the Flutter
# engine injects <style> elements at runtime — and is recorded as a residual
# risk in client_flutter/docs/SECURITY.md rather than papered over.
# ---------------------------------------------------------------------------

# The Flutter SDK ships for linux/amd64 only, so the builder is pinned to it.
# That costs nothing at the far end: `flutter build web` emits JavaScript, wasm
# and assets, none of which are architecture-specific, so the runtime stage is
# free to follow the target platform.
FROM --platform=linux/amd64 instrumentisto/flutter:3.35.7@sha256:affe9ea8b542a622531f55f347898ba86e26722308f12a663c4e6a8b76165894 AS builder

WORKDIR /src

# Resolve dependencies from the manifests alone, so editing Dart source does
# not re-run pub. `resolution: workspace` means pub resolves from the root.
COPY pubspec.yaml pubspec.lock ./
COPY app/pubspec.yaml ./app/
COPY e2e_test/pubspec.yaml ./e2e_test/
RUN flutter pub get

COPY . .

# The fallback constant described in Decision 1. It is a default, not a
# requirement: nothing here needs the real URL to produce a valid image.
ARG BACKEND_BASE_URL_FALLBACK=http://localhost:8000

# --csp                  no dynamically generated code (pairs with the header)
# --no-web-resources-cdn bundle CanvasKit instead of fetching it from
#                        gstatic.com at runtime; keeps the image self-contained
#                        and lets script-src stay 'self'-only
# --no-source-maps       a .map file republishes the Dart source; the bundle is
#                        public, so do not put more in it than has to be there
# --pwa-strategy=none    no service worker. An offline-first worker caches the
#                        app shell, which would serve a stale /config.json after
#                        a redeploy — directly against Decision 1 — and adds a
#                        second, separately-cached script surface for no gain in
#                        a demo that is useless without the backend anyway.
RUN cd app && flutter build web \
      --release \
      --csp \
      --no-web-resources-cdn \
      --no-source-maps \
      --pwa-strategy=none \
      --dart-define=BACKEND_BASE_URL="${BACKEND_BASE_URL_FALLBACK}"

# ---------------------------------------------------------------------------

FROM nginxinc/nginx-unprivileged:1.27-alpine-slim@sha256:ec6b8b1f1bfa594db13e99fc692b9fb816cb7e365927196610f622659de95913 AS runtime

# Pull Alpine security updates so the image does not ship base-layer CVEs — the
# same reason backend/Dockerfile runs apt-get upgrade. Root is needed for apk
# and is given straight back; 101 is this image's own unprivileged nginx user.
USER root
RUN apk --no-cache upgrade
USER 101

ENV PORT=8080
WORKDIR /usr/share/nginx/html

# Nothing from the builder but the bundle: no SDK, no pub cache, no Dart source.
COPY --from=builder --chown=101:101 /src/app/build/web/ ./
COPY --chown=101:101 docker/nginx.conf.template /etc/nginx/nginx.conf.template
COPY --chown=101:101 docker/entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 8080

# /health, not /healthz: Google's edge intercepts the exact path /healthz on
# *.run.app and answers it before it reaches the container, so a probe on it
# proves nothing (harness log, 2026-09-20). Shell form so ${PORT} expands at
# run time — Cloud Run picks the port, the image does not.
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null "http://127.0.0.1:${PORT}/health" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
