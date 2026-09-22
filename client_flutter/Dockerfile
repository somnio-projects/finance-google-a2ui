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
# This app builds with the default web renderer, which is CanvasKit: a
# WebAssembly module. `script-src` therefore has to permit WebAssembly
# instantiation, and the narrow directive for exactly that is
# `'wasm-unsafe-eval'` (Chrome 97+, Firefox 102+, Safari 16.4+). It permits
# WebAssembly and nothing else — `eval()` and `new Function()` stay blocked.
#
# MEASURED, 2026-09-20, both directions:
#   - with 'wasm-unsafe-eval'  -> the app renders, console clean.
#   - with script-src 'self'   -> blank page, and the console says
#     "WebAssembly.compileStreaming(): Compiling or instantiating … blocked by
#      Content Security Policy directive: script-src 'self'".
# So the directive is necessary, and since the page renders with it and no
# other eval token, it is also sufficient. Evidence in PR #49.
#
# The broad `'unsafe-eval'` is NOT needed, because `flutter build web --csp`
# tells dart2js to stop generating code dynamically. Dropping that flag is what
# forces `'unsafe-eval'`, so the flag and the header are a pair: change one and
# the other is wrong. `style-src 'unsafe-inline'` IS required, also measured:
# under `style-src 'self'` the browser blocks the <style> element the engine
# injects and the style attributes it sets, reporting "Applying inline style
# violates … The action has been blocked." It is recorded as a residual risk
# (G-6) in client_flutter/docs/SECURITY.md rather than papered over.
# ---------------------------------------------------------------------------

# The Flutter SDK ships for linux/amd64 only, so the builder is pinned to it.
# That costs nothing at the far end: `flutter build web` emits JavaScript, wasm
# and assets, none of which are architecture-specific, so the runtime stage is
# free to follow the target platform.
#
# The SDK is INSTALLED FROM GOOGLE'S RELEASE ARCHIVE, not taken from a
# community image. That is a change from the first draft of this file, and the
# reason is that no community image can build this workspace:
#
#   - pubspec.lock resolves against `dart: ">=3.12.0"` / `flutter: ">=3.44.0"`,
#     and the first stable pairing that satisfies both is Flutter 3.44.0 /
#     Dart 3.12.0 (releases_linux.json).
#   - instrumentisto/flutter — what this file pinned first — stops at 3.41.6 /
#     Dart 3.11.4 and has not published since 2026-03-27. There is no tag of it
#     that can resolve this lock.
#   - ghcr.io/cirruslabs/flutter:3.44.0 does exist and would fit, but ghcr.io
#     is refused by this project's Docker registry policy, so nobody here can
#     pull it to verify it. A pin that cannot be pulled is a pin that cannot be
#     checked, which is the thing this Dockerfile is trying not to ship.
#
# So: Debian by digest, plus the SDK tarball by version AND by the SHA-256 that
# Google publishes for it. Both halves are immutable and both are verifiable
# offline, which is strictly better provenance than a community image digest —
# it narrows gap G-8 in docs/SECURITY.md rather than restating it.
#
# WHICH version: whatever `client_flutter/.fvmrc` says — and the lock is what
# chose it, not the manifest. The reasoning below is why the pin is a 3.47.x
# and not the floor; the file, not this comment, is where the number lives.
#
# `flutter: ">=3.44.0"` in pubspec.lock is only a floor, and building against
# the floor is not the same as building against the lock. 3.44.9 gets as far as
# resolution and then `pub get --enforce-lockfile` says
# "Unable to satisfy `pubspec.yaml` using `pubspec.lock` … Would change 14
# dependencies", because the SDK *vendors* some of what the lock pins:
# Flutter 3.44.9 pins `meta 1.18.0` and `vector_math 2.2.0` exactly, while the
# checked-in lock holds `meta 1.19.0` and `vector_math 2.4.2`. Only 3.47.x
# widens those to `^1.18.3` / `^2.4.0` and admits the locked versions. So the
# lock was generated by a 3.47 SDK, and 3.47.5 (the current stable, Dart
# 3.13.4) is the one that reproduces it byte for byte.
#
# The lesson worth keeping: the lock's own `flutter:` range does not identify
# the SDK that produced it. `--enforce-lockfile` does, by failing.
#
# client_flutter/pubspec.yaml is deliberately NOT touched. It declares
# `flutter: ">=3.35.7"` / `sdk: ">=3.10.0"`, which 3.47.5 satisfies, so the
# build needs no change there — but that floor is still a lie (3.35.7 ships
# Dart 3.9.2 and fails version solving outright, and no version in the 3.35–
# 3.44 range can satisfy the lock either), and correcting a manifest belongs to
# GGU-1. It stays as gap G-12.
FROM --platform=linux/amd64 debian:12-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251 AS builder

# Pull base-layer security updates, and install exactly what the SDK needs to
# unpack and run: git (the SDK is a git checkout and refuses to run without
# it), xz/unzip for the archives, curl and CA roots for the download.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq unzip xz-utils \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# The SDK version is READ from .fvmrc, never written here.
#
# This file used to carry `ARG FLUTTER_VERSION=3.47.5` while
# `client_flutter/.fvmrc` pinned **3.47.3**, so the image shipped a bundle
# compiled by a different SDK than the one `make gate` and `client-ci` prove
# the app against — GGU-94's defect, rebuilt in a Dockerfile, where
# `scripts/check_gate_pairs.sh` was not looking. Found on 2026-09-22 while
# building the same stage for `frontend/`; the check now reads Dockerfiles too,
# so this cannot come back silently.
#
# A checksum cannot be derived from a version, so docker/flutter-sdk-checksums.json
# maps version → the SHA-256 Google publishes in releases_linux.json. That is
# a lookup table keyed by the pin, not a second pin: bump `.fvmrc` without
# adding the row and the build stops and names the row to add, rather than
# fetching a tarball it cannot verify.
COPY .fvmrc /tmp/pin/.fvmrc
COPY docker/flutter-sdk-checksums.json /tmp/pin/checksums.json

RUN set -eu; \
    version="$(jq -r .flutter /tmp/pin/.fvmrc)"; \
    sha="$(jq -r --arg v "$version" '.[$v] // empty' /tmp/pin/checksums.json)"; \
    if [ -z "$sha" ]; then \
      echo "Dockerfile: .fvmrc pins Flutter ${version}, and docker/flutter-sdk-checksums.json has no checksum for it." >&2; \
      echo "Dockerfile: add the sha256 for that release from" >&2; \
      echo "Dockerfile:   https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json" >&2; \
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
# must not phone home, and `flutter --version` warms the tool cache so that the
# first real command is not also a download.
RUN flutter config --no-analytics >/dev/null \
 && flutter --version

WORKDIR /src

# Resolve dependencies from the manifests alone, so editing Dart source does
# not re-run pub. `resolution: workspace` means pub resolves from the root.
#
# --enforce-lockfile: resolve to exactly what pubspec.lock pins, or fail. The
# default `pub get` would silently re-resolve if the lock did not fit the SDK,
# and a container that quietly builds a different dependency set than the one
# reviewed is worse than one that stops. This is also what makes the
# "resolved from a checked-in lockfile" row in docs/SECURITY.md true.
COPY pubspec.yaml pubspec.lock ./
COPY app/pubspec.yaml ./app/
COPY e2e_test/pubspec.yaml ./e2e_test/
RUN flutter pub get --enforce-lockfile

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
