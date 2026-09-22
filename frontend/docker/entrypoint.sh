#!/bin/sh
# Start the static server for the A2UI client's web bundle.
#
# Unlike client_flutter/docker/entrypoint.sh, this one writes NO /config.json:
# this app's configuration is compiled into the bundle (Decision 1 in
# ../Dockerfile), because its deployable is a static Firebase Hosting release
# and Hosting has no process to render one.
#
# What is left is the nginx config, which still has to be rendered because the
# Content-Security-Policy names the exact origins this build talks to, and
# because Cloud Run — not the image — picks the port.
#
# Everything is written under /tmp, which the container mounts as tmpfs; the
# image's own root filesystem is read-only.

set -eu

: "${PORT:=8080}"

# Baked by the runtime stage from the same build args the bundle was compiled
# with. They are re-readable as environment variables so the rendered policy
# is inspectable in `docker inspect` and in this log line, not so they can be
# changed: override one and the header will name an origin the compiled bundle
# never calls. The log below prints what was rendered for exactly that reason.
if [ -z "${APP_BACKEND_ORIGIN:-}" ]; then
    echo "entrypoint: APP_BACKEND_ORIGIN is required and has no default." >&2
    echo "entrypoint: it is the API origin compiled into this bundle, and the" >&2
    echo "entrypoint: only one the CSP will permit. A fallback would mean a" >&2
    echo "entrypoint: policy that does not match the app it is protecting." >&2
    exit 1
fi

# Validated, not trusted. The value is interpolated into a CSP directive, so
# anything outside this shape could close one directive and open another.
# Same posture as the backend's settings: a bad required value crashes at
# start, it never degrades into a guess.
if ! echo "$APP_BACKEND_ORIGIN" | grep -Eq '^https?://[A-Za-z0-9._~-]+(:[0-9]{1,5})?/?$'; then
    echo "entrypoint: APP_BACKEND_ORIGIN is not a bare http(s) origin: ${APP_BACKEND_ORIGIN}" >&2
    echo "entrypoint: expected scheme://host[:port], with no path, query or credentials." >&2
    exit 1
fi

# A CSP source is an origin — a trailing slash is not part of one.
connect_src="${APP_BACKEND_ORIGIN%/}"

# The sign-in popup is hosted on the Firebase auth domain. A build with no
# Firebase config (the local stack default) opens no popup at all, so the
# directive stays empty rather than naming a host this bundle cannot reach —
# a CSP that permits more than the app does is a CSP nobody can review.
frame_src=""
if [ -n "${APP_FIREBASE_AUTH_DOMAIN:-}" ]; then
    if ! echo "$APP_FIREBASE_AUTH_DOMAIN" | grep -Eq '^[A-Za-z0-9.-]+$'; then
        echo "entrypoint: APP_FIREBASE_AUTH_DOMAIN is not a bare host: ${APP_FIREBASE_AUTH_DOMAIN}" >&2
        exit 1
    fi
    frame_src=" https://${APP_FIREBASE_AUTH_DOMAIN}"
    # The Firebase JS SDK talks to these two, and only these two, for
    # sign-in and for refreshing an ID token. Named explicitly rather than
    # as *.googleapis.com, which would also admit every other Google API.
    connect_src="${connect_src} https://identitytoolkit.googleapis.com https://securetoken.googleapis.com"
fi

runtime_dir=/tmp/nginx
mkdir -p "${runtime_dir}/body" \
         "${runtime_dir}/proxy" \
         "${runtime_dir}/fastcgi" \
         "${runtime_dir}/uwsgi" \
         "${runtime_dir}/scgi"

# envsubst is given the exact variable list: without it, it would also expand
# nginx's own $uri, $host and $request_method into empty strings and the
# resulting config would still be valid enough to start.
# shellcheck disable=SC2016 # the single quotes are required, not a mistake:
# envsubst takes the variable list as a literal `${NAME}` string and does the
# substituting itself. Double quotes would let the shell expand the list first,
# leaving envsubst an empty allow-list — which is the "expand everything" mode
# the comment above exists to avoid.
PORT="${PORT}" CONNECT_SRC="${connect_src}" FRAME_SRC="${frame_src}" \
    envsubst '${PORT} ${CONNECT_SRC} ${FRAME_SRC}' \
    < /etc/nginx/nginx.conf.template \
    > "${runtime_dir}/nginx.conf"

echo "entrypoint: serving the A2UI bundle on :${PORT}"
echo "entrypoint: connect-src ${connect_src}"
echo "entrypoint: frame-src  'self'${frame_src}"

exec nginx -c "${runtime_dir}/nginx.conf" -g 'daemon off;'
