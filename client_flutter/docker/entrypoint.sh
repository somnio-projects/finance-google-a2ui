#!/bin/sh
# Start the static server for the Flutter web bundle.
#
# Two things have to happen before nginx starts, and both exist because the
# image is environment-agnostic (Decision 1 in ../Dockerfile):
#
#   1. /config.json is written from $BACKEND_BASE_URL, so the browser learns
#      the API origin at run time instead of from a constant compiled into the
#      bundle. One image is then promotable by digest, the way the backend's is.
#   2. The nginx config is rendered from the template, because the CSP's
#      connect-src has to name that same origin.
#
# Everything is written under /tmp, which the container mounts as tmpfs; the
# image's own root filesystem is read-only.

set -eu

: "${PORT:=8080}"

if [ -z "${BACKEND_BASE_URL:-}" ]; then
    echo "entrypoint: BACKEND_BASE_URL is required and has no default." >&2
    echo "entrypoint: it is the API origin this client talks to; a fallback" >&2
    echo "entrypoint: would mean shipping a client pointed at the wrong API." >&2
    exit 1
fi

# Validated, not trusted. The value is interpolated into a JSON document and
# into a CSP directive, so anything outside this shape could close one and open
# something else. Same posture as the backend's settings: a bad required value
# crashes at start, it never degrades into a guess.
if ! echo "$BACKEND_BASE_URL" | grep -Eq '^https?://[A-Za-z0-9._~-]+(:[0-9]{1,5})?/?$'; then
    echo "entrypoint: BACKEND_BASE_URL is not a bare http(s) origin: ${BACKEND_BASE_URL}" >&2
    echo "entrypoint: expected scheme://host[:port], with no path, query or credentials." >&2
    exit 1
fi

# A CSP source is an origin — a trailing slash is not part of one.
connect_src="${BACKEND_BASE_URL%/}"

runtime_dir=/tmp/nginx
mkdir -p "${runtime_dir}/www" \
         "${runtime_dir}/body" \
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
PORT="${PORT}" CONNECT_SRC="${connect_src}" \
    envsubst '${PORT} ${CONNECT_SRC}' \
    < /etc/nginx/nginx.conf.template \
    > "${runtime_dir}/nginx.conf"

printf '{"backendBaseUrl":"%s"}\n' "${connect_src}" > "${runtime_dir}/www/config.json"

echo "entrypoint: serving the web bundle on :${PORT}, API origin ${connect_src}"

exec nginx -c "${runtime_dir}/nginx.conf" -g 'daemon off;'
