FROM openresty/openresty:1.25.3.2-alpine

COPY nginx.conf  /usr/local/openresty/nginx/conf/nginx.conf
COPY conf.d/     /etc/nginx/conf.d/
COPY lua/        /etc/nginx/lua/

RUN mkdir -p /var/log/nginx

EXPOSE 80

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
