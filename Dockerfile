
# see: https://github.com/nginxinc/docker-nginx/blob/1.15.0/mainline/alpine/Dockerfile

FROM nginx:1.15.0-alpine

RUN apk add --update jq \
    && rm -rf /tmp/* /var/cache/apk/*

COPY docker/*.sh /
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/*.tpl /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
