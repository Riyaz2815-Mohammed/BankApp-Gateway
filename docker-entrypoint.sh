#!/usr/bin/env sh
set -e

export SPRING_BACKEND_HOST="${SPRING_BACKEND_HOST:-spring-boot:8080}"
export NEXTJS_FRONTEND_HOST="${NEXTJS_FRONTEND_HOST:-nextjs:3000}"
export KEYCLOAK_HOST="${KEYCLOAK_HOST:-keycloak:8080}"

envsubst '${SPRING_BACKEND_HOST} ${NEXTJS_FRONTEND_HOST} ${KEYCLOAK_HOST}' \
  < /etc/nginx/conf.d/upstreams.conf.template \
  > /etc/nginx/conf.d/upstreams.conf

exec /usr/local/openresty/bin/openresty -g "daemon off;"
