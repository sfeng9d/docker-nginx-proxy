#!/usr/bin/env sh

set -e

if [ "$1" == 'nginx' ]; then
    if [ -f /etc/nginx/conf.d/default.conf ]; then rm -f /etc/nginx/conf.d/default.conf; fi
    /render.sh "/etc/nginx/conf.d"
    exec "$@"
else
    exec "$@"
fi
