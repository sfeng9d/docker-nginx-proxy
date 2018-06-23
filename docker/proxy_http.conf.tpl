
# Nginx does not support CONNECT method, it can not proxy https sites (can reverse proxy).



server {
    resolver                  <SERVER_RESOLVER>;
    resolver_timeout          5s;

    listen                    0.0.0.0:80;

    server_name               <SERVER_NAME>;









    location / {
        proxy_pass            $scheme://$host$request_uri;
        proxy_set_header      Host $http_host;
    }
}
