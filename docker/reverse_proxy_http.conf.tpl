
upstream backend_http_<SERVER_NAME> {
  server                      <BACKEND_HOST_PORT>;
}

server {



    listen                    0.0.0.0:<SERVER_PORT>;

    server_name               <SERVER_NAME>;









    location <SERVER_LOCATION> {

        <BASIC_AUTH_SETTING>

        proxy_redirect        off;
        # note: not $host:$proxy_port, $proxy_port is backend_port
        proxy_set_header      Host $host:<SERVER_PORT>;
        proxy_set_header      X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header      X-Forwarded-Proto $scheme;
        proxy_set_header      X-Real-IP $remote_addr;

        proxy_pass            <SERVER_PROXY_PASS>;
    }
}
