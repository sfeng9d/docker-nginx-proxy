#!/usr/bin/env sh

set -e
sudo socat TCP-LISTEN:80,fork TCP:127.0.0.1:1080 &
sudo socat TCP-LISTEN:443,fork TCP:127.0.0.1:1443 &

if [ "$1" == 'nginx' ]; then
    /render.sh "/etc/nginx/conf.d"
    exec "$@"
else
    exec "$@"
fi
