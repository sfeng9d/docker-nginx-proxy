
# see: https://github.com/nginxinc/docker-nginx/blob/1.15.0/mainline/alpine/Dockerfile

FROM nginx:1.15.0-alpine

COPY docker/*.sh /
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/*.tpl /

RUN apk add --update jq shadow socat sudo\
 && usermod -u 1000 nginx \
 && groupmod -g 1000 nginx \
 && chown nginx:nginx /var/run \
 && chown -R nginx:nginx /var/log/nginx \
 && echo "nginx ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/nginx \
 && if [ -f /etc/nginx/conf.d/default.conf ]; then rm -f /etc/nginx/conf.d/default.conf; fi \
 && rm -rf /tmp/* /var/cache/apk/*

USER nginx

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
