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


# arguments: server_name, server_port, server_resolver, target_directory
function proxy() {
    local server_name="$1"
    local server_port="$2"
    local server_resolver="$3"
    local target_directory="$4"
    local target="${target_directory}/proxy_${server_name}.conf"
    local template="proxy_http.conf.tpl"

    echo "server_name: ${server_name}"
    echo "server_port: ${server_port}"
    echo "server_resolver: ${server_resolver}"
    echo "target_directory: ${target_directory}"
    echo "target: ${target}"
    echo "template: ${template}"

    sed "s#<SERVER_PORT>#${server_port}#" ${template} | \
        sed "s#<SERVER_RESOLVER>#${server_resolver}#" | \
        sed "s#<SERVER_NAME>#${server_name}#" > ${target}

    echo "${target} content:"
    cat ${target}
}

# arguments: backend_host_port, basic_auth_header, server_location, server_name, server_port, server_protocol, server_proxy_pass, target_directory
function reverse_proxy() {
    local backend_host_port="$1"
    local basic_auth_header="$2"
    local server_location="$3"
    local server_name="$4"
    local server_port="$5"
    local server_protocol="$6"
    local server_proxy_pass="$7"
    local target_directory="$8"
    local target="${target_directory}/reverse_proxy_${server_protocol}_${server_name}.conf"
    local template="reverse_proxy_${server_protocol}.conf.tpl"

    echo "backend_host_port: ${backend_host_port}"
    echo "basic_auth_header: ${basic_auth_header}"
    echo "server_location: ${server_location}"
    echo "server_name: ${server_name}"
    echo "server_port: ${server_port}"
    echo "server_proxy_pass: ${server_proxy_pass}"
    echo "target_directory: ${target_directory}"
    echo "target: ${target}"
    echo "template: ${template}"

    sed "s#<BACKEND_HOST_PORT>#${backend_host_port}#; s#<SERVER_PORT>#${server_port}#" ${template} | \
        sed "s#<SERVER_LOCATION>#${server_location}#" | \
        sed "s#<SERVER_NAME>#${server_name}#" | \
        sed "s#<SERVER_PROXY_PASS>#${server_proxy_pass}#" > ${target}

    if [ "${server_protocol}" == "https" ]; then
        # see: https://stackoverflow.com/questions/25204179/removing-subdomain-with-bash
        if [ -z "${SERVER_DOMAIN}" ]; then SERVER_DOMAIN=$(expr match "${server_name}" '.*\.\(.*\..*\)'); fi
        if [ -z "${SERVER_DOMAIN}" ]; then SERVER_DOMAIN="${server_name}"; fi
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

# for test (cd docker; ./render.sh $(pwd)/../data)
#NGINX_PROXY_CONFIG="[\
#  {\"host\": \"172.16.238.31\", \"port\": 5000, \"pass\": \"\", \"user\": \"\",\
#    \"server_name\": \"docker-registry.local\", \"server_port\": 443, \"server_protocol\": \"https\"}
#]
#"

TARGET_DIRECTORY="$1"

echo NGINX_PROXY_CONFIG: ${NGINX_PROXY_CONFIG}
echo TARGET_DIRECTORY: ${TARGET_DIRECTORY}

for row in $(echo "${NGINX_PROXY_CONFIG}" | jq -r '.[] | @base64'); do
    _jq() {
     echo ${row} | base64 -d | jq -r ${1}
    }

    BACKEND_HOST=$(_jq '.host')
    SERVER_PORT=$(_jq '.server_port')

    if [ "${BACKEND_HOST}" != "null" ] && [ ! -z "${BACKEND_HOST}" ]; then
        # reverse_proxy mode
        echo "BACKEND_HOST not null, reverse_proxy mode."
        SERVER_MODE="reverse_proxy"
    else
        # proxy mode
        echo "BACKEND_HOST is null, proxy mode."
        SERVER_MODE="proxy"
    fi

    #echo "${SERVER_NAMES}" | sed -n 1'p' | tr ',' '\n' | while read SERVER_NAME; do echo ${SERVER_NAME}; done
    if [ "${SERVER_PORT}" == "null" ] || [ -z "${SERVER_PORT}" ]; then SERVER_PORT="80"; fi


    if [ "${SERVER_MODE}" == "reverse_proxy" ]; then
        BACKEND_PORT=$(_jq '.port')
        BACKEND_PROTOCOL=$(_jq '.protocol')
        BASIC_AUTH_PASS=$(_jq '.pass')
        BASIC_AUTH_USER=$(_jq '.user')
        SERVER_LOCATION=$(_jq '.server_location')
        SERVER_NAME=$(_jq '.server_name')
        SERVER_PROTOCOL=$(_jq '.server_protocol')
        SERVER_PROXY_PASS_CONTEXT=$(_jq '.server_proxy_pass_context')

        if [ "${BACKEND_PORT}" == "null" ] || [ -z "${BACKEND_PORT}" ]; then BACKEND_PORT="8081"; fi
        if [ "${BACKEND_PROTOCOL}" == "null" ] || [ -z "${BACKEND_PROTOCOL}" ]; then BACKEND_PROTOCOL="http"; fi
        if [ "${BASIC_AUTH_PASS}" != "null" ] && [ ! -z "${BASIC_AUTH_PASS}" ] && [ "${BASIC_AUTH_USER}" != "null" ] && [ ! -z "${BASIC_AUTH_USER}" ]; then
            BASIC_AUTH_HEADER="'Basic $(echo -ne "${BASIC_AUTH_USER}:${BASIC_AUTH_PASS}" | base64)'";
        fi
        if [ "${SERVER_LOCATION}" == "null" ] || [ -z "${SERVER_LOCATION}" ]; then SERVER_LOCATION="/"; fi
        if [ "${SERVER_NAME}" == "null" ] || [ -z "${SERVER_NAME}" ]; then SERVER_NAME="nexus.local"; fi
        if [ "${SERVER_PROTOCOL}" == "null" ] || [ -z "${SERVER_PROTOCOL}" ]; then SERVER_PROTOCOL="http"; fi
        SERVER_PROXY_PASS="${BACKEND_PROTOCOL}://backend_${SERVER_PROTOCOL}_${SERVER_NAME}"
        if [ "${SERVER_PROXY_PASS_CONTEXT}" != "null" ] && [ ! -z "${SERVER_PROXY_PASS_CONTEXT}" ]; then SERVER_PROXY_PASS="${SERVER_PROXY_PASS}${SERVER_PROXY_PASS_CONTEXT}"; fi

        echo "BACKEND_HOST: ${BACKEND_HOST}, BACKEND_PORT: ${BACKEND_PORT}, BACKEND_PROTOCOL: ${BACKEND_PROTOCOL}"
        echo "BASIC_AUTH_HEADER: ${BASIC_AUTH_HEADER}"
        echo "SERVER_LOCATION: ${SERVER_LOCATION}"
        echo "SERVER_NAME: ${SERVER_NAME}"
        echo "SERVER_PORT: ${SERVER_PORT}"
        echo "SERVER_PROTOCOL: ${SERVER_PROTOCOL}"
        echo "SERVER_PROXY_PASS: ${SERVER_PROXY_PASS}"
        echo "TARGET_DIRECTORY: ${TARGET_DIRECTORY}"

        reverse_proxy "${BACKEND_HOST}:${BACKEND_PORT}" "${BASIC_AUTH_HEADER}" "${SERVER_LOCATION}" "${SERVER_NAME}" "${SERVER_PORT}" "${SERVER_PROTOCOL}" "${SERVER_PROXY_PASS}" "${TARGET_DIRECTORY}"
    else
        if [ "${SERVER_NAME}" == "null" ] || [ -z "${SERVER_NAME}" ]; then SERVER_NAME="*.local"; fi
        SERVER_RESOLVER=$(cat /etc/resolv.conf | grep -i nameserver | head -n1 | cut -d ' ' -f2)

        echo "SERVER_NAME: ${SERVER_NAME}"
        echo "SERVER_PORT: ${SERVER_PORT}"
        echo "SERVER_RESOLVER: ${SERVER_RESOLVER}"
        echo "TARGET_DIRECTORY: ${TARGET_DIRECTORY}"

        proxy "${SERVER_NAME}" "${SERVER_PORT}" "${SERVER_RESOLVER}" "${TARGET_DIRECTORY}"
    fi
done
