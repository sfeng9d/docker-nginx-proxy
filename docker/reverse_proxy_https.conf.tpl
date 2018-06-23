
upstream backend_https_<SERVER_NAME> {
  server                      <BACKEND_HOST_PORT>;
}

server {



    listen                    <SERVER_PORT> ssl http2;
    listen                    [::]:<SERVER_PORT> ssl http2;
    server_name               <SERVER_NAME>;

    # [warn] the "ssl" directive is deprecated, use the "listen ... ssl" directive instead
    #ssl on;
    ssl_certificate           /etc/nginx/certs/live/<SERVER_DOMAIN>/fullchain.pem;
    ssl_certificate_key       /etc/nginx/certs/live/<SERVER_DOMAIN>/privkey.pem;
    ssl_ciphers               HIGH:!kEDH:!ADH:!MD5:@STRENGTH;
    ssl_prefer_server_ciphers on;
    ssl_session_cache         shared:TLSSSL:16m;
    ssl_session_timeout       10m;

    location <SERVER_LOCATION> {

        <BASIC_AUTH_SETTING>

        proxy_redirect        off;
        proxy_set_header      Host $host;
        proxy_set_header      X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header      X-Forwarded-Proto "https";
        proxy_set_header      X-Real-IP $remote_addr;

        proxy_pass            <SERVER_PROXY_PASS>;
    }
}
