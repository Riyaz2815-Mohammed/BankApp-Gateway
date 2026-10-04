FROM openresty/openresty:1.25.3.2-alpine

RUN apk add --no-cache perl curl \
 && opm get ledgetech/lua-resty-http cdbattags/lua-resty-jwt

COPY nginx.conf             /usr/local/openresty/nginx/conf/nginx.conf
COPY conf.d/                /etc/nginx/conf.d/
COPY lua/                   /etc/nginx/lua/
COPY docker-entrypoint.sh   /usr/local/bin/docker-entrypoint.sh

RUN mkdir -p /var/log/nginx /etc/nginx/certs \
 && chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["docker-entrypoint.sh"]
