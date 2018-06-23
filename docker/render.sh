#!/usr/bin/env sh


# tests:
#
#BACKEND_HOST="nexus3" BACKEND_PORT="28081" SERVER_NAMES="nexus3.example.org,nexus3.example.net" SERVER_PROTOCOL="http" ./render.sh $(pwd)/../data
#BACKEND_HOST="nexus3" BACKEND_PORT="28081" SERVER_NAMES="nexus3.example.org,nexus3.example.net" SERVER_PROTOCOL="https" ./render.sh $(pwd)/../data
#./render.sh $(pwd)/../data

# in container
#docker run --rm -it cirepo/nginx-proxy:1.15.0-alpine /bin/sh
#BACKEND_HOST="nexus3" BACKEND_PORT="28081" SERVER_NAMES="nexus3.example.org,nexus3.example.net" SERVER_PROTOCOL="http" ./render.sh /etc/nginx/conf.d
#BACKEND_HOST="nexus3" BACKEND_PORT="28081" SERVER_NAMES="nexus3.example.org,nexus3.example.net" SERVER_PROTOCOL="https" ./render.sh /etc/nginx/conf.d
#./render.sh /etc/nginx/conf.d


# arguments: server_name, server_resolver, target_directory
function proxy() {
    local server_name="$1"
    local server_resolver="$2"
    local target_directory="$3"
    local target="${target_directory}/proxy_${server_name}.conf"
    local template="proxy_http.conf.tpl"

    sed "s#<SERVER_RESOLVER>#${server_resolver}#" ${template} | \
        sed "s#<SERVER_NAME>#${server_name}#" > ${target}

    echo "${target} content:"
    cat ${target}
}

# arguments: backend_host_port, basic_auth_header, server_location, server_name, server_protocol, server_proxy_pass, target_directory
function reverse_proxy() {
    local backend_host_port="$1"
    local basic_auth_header="$2"
    local server_location="$3"
    local server_name="$4"
    local server_protocol="$5"
    local server_proxy_pass="$6"
    local target_directory="$7"
    local target="${target_directory}/reverse_proxy_${server_protocol}_${server_name}.conf"
    local template="reverse_proxy_${server_protocol}.conf.tpl"

    sed "s#<BACKEND_HOST_PORT>#${backend_host_port}#; s#<SERVER_LOCATION>#${server_location}#" ${template} | \
        sed "s#<SERVER_NAME>#${server_name}#" | \
        sed "s#<SERVER_PROXY_PASS>#${server_proxy_pass}#" > ${target}

    if [ "${server_protocol}" == "https" ]; then
        #if [ -z "${SERVER_DOMAIN}" ]; then SERVER_DOMAIN="${server_name}"; fi
        # see: https://stackoverflow.com/questions/25204179/removing-subdomain-with-bash
        if [ -z "${SERVER_DOMAIN}" ]; then SERVER_DOMAIN=$(expr match "${server_name}" '.*\.\(.*\..*\)'); fi
        sed -i "s|<SERVER_DOMAIN>|${SERVER_DOMAIN}|" ${target}
    fi

    # replace
    #    <BASIC_AUTH_SETTING>
    # to
    #    # add basic auth header
    #    set $authorization $http_authorization;
    #    if ($authorization = '') {
    #      set $authorization ${basic_auth_header};
    #    }
    #    proxy_set_header Authorization $authorization;
    # if BASIC_AUTH_HEADER present
    if [ ! -z "${basic_auth_header}" ]; then
        sed -i "s|<BASIC_AUTH_SETTING>|# add basic auth header\\n    set \$authorization \$http_authorization;\\n    if (\$authorization = '') {\\n      set \$authorization ${basic_auth_header};\\n    }\\n    proxy_set_header Authorization \$authorization;|" ${target}
    else
        sed -i "s|<BASIC_AUTH_SETTING>|# no basic auth header|" ${target}
    fi

    echo "${target} content:"
    cat ${target}
}

TARGET_DIRECTORY="$1"

if [ ! -z "${BACKEND_HOST}" ]; then
    # reverse_proxy mode
    echo "BACKEND_HOST not blank, reverse_proxy mode."
    if [ -z "${BACKEND_PORT}" ]; then BACKEND_PORT="8081"; fi
    if [ -z "${BACKEND_PROTOCOL}" ]; then BACKEND_PROTOCOL="http"; fi

    if [ ! -z "${BASIC_AUTH_PASS}" ] && [ ! -z "${BASIC_AUTH_USER}" ]; then BASIC_AUTH_HEADER="'Basic $(echo -ne "${BASIC_AUTH_USER}:${BASIC_AUTH_PASS}" | base64)'"; fi

    if [ -z "${SERVER_LOCATION}" ]; then SERVER_LOCATION="/"; fi
    if [ -z "${SERVER_NAMES}" ]; then SERVER_NAMES="nexus.local"; fi
    if [ -z "${SERVER_PROTOCOL}" ]; then SERVER_PROTOCOL="http"; fi
    SERVER_PROXY_PASS="${BACKEND_PROTOCOL}://backend"
    if [ ! -z "${SERVER_PROXY_PASS_CONTEXT}" ]; then SERVER_PROXY_PASS="${SERVER_PROXY_PASS}${SERVER_PROXY_PASS_CONTEXT}"; fi

    echo "${SERVER_NAMES}" | sed -n 1'p' | tr ',' '\n' | while read SERVER_NAME; do
        reverse_proxy "${BACKEND_HOST}:${BACKEND_PORT}" "${BASIC_AUTH_HEADER}" "${SERVER_LOCATION}" "${SERVER_NAME}" "${SERVER_PROTOCOL}" "${SERVER_PROXY_PASS}" "${TARGET_DIRECTORY}"
    done
else
    # proxy mode
    echo "BACKEND_HOST is blank, proxy mode."
    SERVER_RESOLVER=$(cat /etc/resolv.conf | grep -i nameserver | head -n1 | cut -d ' ' -f2)
    if [ -z "${SERVER_NAMES}" ]; then SERVER_NAMES="*.local"; fi

    echo "${SERVER_NAMES}" | sed -n 1'p' | tr ',' '\n' | while read SERVER_NAME; do
        proxy "${SERVER_NAME}" "${SERVER_RESOLVER}" "${TARGET_DIRECTORY}"
    done
fi
