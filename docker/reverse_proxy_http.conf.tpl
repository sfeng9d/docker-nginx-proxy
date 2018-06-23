
upstream backend {
  server                      <BACKEND_HOST_PORT>;
}

server {





    server_name               <SERVER_NAME>;









    location <SERVER_LOCATION> {

        <BASIC_AUTH_SETTING>

        proxy_redirect        off;
        proxy_set_header      Host $host;
        proxy_set_header      X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header      X-Forwarded-Proto $scheme;
        proxy_set_header      X-Real-IP $remote_addr;

        proxy_pass            <SERVER_PROXY_PASS>;
    }
}