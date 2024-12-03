#!/bin/bash
# chris.rust@solarwinds.com - 20180227
set -e

SWISNAP_HOME="/opt/SolarWinds/Snap"
PLUGINS_DIR="${SWISNAP_HOME}/etc/plugins.d"
TASK_AUTOLOAD_DIR="${SWISNAP_HOME}/etc/tasks-autoload.d"
CONFIG_FILE="${SWISNAP_HOME}/etc/config.yaml"
PUBLISHER_PROCESSES_CONFIG="${PLUGINS_DIR}/publisher-processes.yaml"
PUBLISHER_APPOPTICS_CONFIG="${PLUGINS_DIR}/publisher-appoptics.yaml"
PUBLISHER_LOGS_CONFIG="${PLUGINS_DIR}/publisher-logs.yaml"

enable_incluster() {
    local task_file="${1}"
    yq eval -i '.plugins[0].config.kubernetes.incluster = true' "${task_file}"
}

swisnap_config_setup() {
    echo "Running swisnap_config_setup"
    # SOLARWINDS_TOKEN is required. Please note, that APPOPTICS_TOKEN is left for preserving backward compatibility
    if [ -n "${SOLARWINDS_TOKEN}" ] && [ "${SOLARWINDS_TOKEN}" != 'SOLARWINDS_TOKEN' ]; then
        SWI_TOKEN="${SOLARWINDS_TOKEN}"
    elif [ -n "${APPOPTICS_TOKEN}" ] && [ "${APPOPTICS_TOKEN}" != 'APPOPTICS_TOKEN' ]; then
        SWI_TOKEN="${APPOPTICS_TOKEN}"
    else
        echo "Please set SOLARWINDS_TOKEN. Exiting"
        exit 1
    fi

    yq eval -i '.v1.publisher."publisher-appoptics".all.token = "'"${SWI_TOKEN}"'"' "${PUBLISHER_APPOPTICS_CONFIG}"
    yq eval -i '.v2.publisher."publisher-appoptics".all.endpoint.token = "'"${SWI_TOKEN}"'"' "${PUBLISHER_APPOPTICS_CONFIG}"    
    yq eval -i '.v2.publisher."publisher-processes".all.endpoint.token = "'"${SWI_TOKEN}"'"' "${PUBLISHER_PROCESSES_CONFIG}"   

    # Use APPOPTICS_HOSTNAME as hostname_alias
    if [ -n "${APPOPTICS_HOSTNAME}" ]; then
        yq eval -i '.v1.publisher."publisher-appoptics".all.hostname_alias = "'"${APPOPTICS_HOSTNAME}"'"' "${PUBLISHER_APPOPTICS_CONFIG}"
        yq eval -i '.v2.publisher."publisher-appoptics".all.endpoint.hostname_alias = "'"${APPOPTICS_HOSTNAME}"'"' "${PUBLISHER_APPOPTICS_CONFIG}"
        yq eval -i '.v2.publisher."publisher-processes".all.endpoint.hostname_alias = "'"${APPOPTICS_HOSTNAME}"'"' "${PUBLISHER_PROCESSES_CONFIG}"
    fi

    if [ -n "${LOG_LEVEL}" ]; then
        yq eval -i '.log_level = strenv(LOG_LEVEL)' "${CONFIG_FILE}"
    fi

    if [ "${SWISNAP_SECURE}" = true ]; then
        FLAGS=("--keyring-paths" "${SWISNAP_HOME}/.gnupg/")
    else
        yq eval -i '.control.plugin_trust_level = 0' "${CONFIG_FILE}"
    fi

    yq eval -i '.log_path = strenv(LOG_PATH) // "/proc/self/fd/1"' "${CONFIG_FILE}"
    yq eval -i '.restapi.addr = "tcp://0.0.0.0:21413"' "${CONFIG_FILE}"

    # Logs Publishers releated configs
    if [ -n "${LOGGLY_TOKEN}" ] && [ "${LOGGLY_TOKEN}" != 'LOGGLY_TOKEN' ]; then
        LOGGLY_PUBL_TOKEN="${LOGGLY_TOKEN}"
    else
        LOGGLY_PUBL_TOKEN="${SWI_TOKEN}"
    fi

    yq eval -i '.v2.publisher."loggly-http".all.token = "'"${LOGGLY_PUBL_TOKEN}"'"' "${PUBLISHER_LOGS_CONFIG}"
    yq eval -i '.v2.publisher."loggly-http-bulk".all.token = "'"${LOGGLY_PUBL_TOKEN}"'"' "${PUBLISHER_LOGS_CONFIG}"
    yq eval -i '.v2.publisher."loggly-syslog".all.token = "'"${LOGGLY_PUBL_TOKEN}"'"' "${PUBLISHER_LOGS_CONFIG}"

    if [ -n "${PAPERTRAIL_TOKEN}" ] && [ "${PAPERTRAIL_TOKEN}" != 'PAPERTRAIL_TOKEN' ]; then
        PAPERTRAIL_PUBL_TOKEN="${PAPERTRAIL_TOKEN}"
    else
        PAPERTRAIL_PUBL_TOKEN="${SWI_TOKEN}"
    fi

    yq eval -i '.v2.publisher."swi-logs-http-bulk".all.token = "'"${PAPERTRAIL_PUBL_TOKEN}"'"' "${PUBLISHER_LOGS_CONFIG}"
    yq eval -i '.v2.publisher."swi-logs-http".all.token = "'"${PAPERTRAIL_PUBL_TOKEN}"'"' "${PUBLISHER_LOGS_CONFIG}"

    if [ -n "${PAPERTRAIL_HOST}" ] && [ -n "${PAPERTRAIL_PORT}" ]; then
        yq eval -i '.v2.publisher."papertrail-syslog".all.host = strenv(PAPERTRAIL_HOST)' "${PUBLISHER_LOGS_CONFIG}"
        yq eval -i '.v2.publisher."papertrail-syslog".all.port = strenv(PAPERTRAIL_PORT)' "${PUBLISHER_LOGS_CONFIG}"
    fi


}

run_plugins_with_default_configs() {
    # Set to true to enable or disable specific plugins
    if [ "${SWISNAP_ENABLE_APACHE}" = "true" ]; then
        apache_plugin_config="${TASK_AUTOLOAD_DIR}/task-apache.yaml"
        if check_if_plugin_supported Apache "${apache_plugin_config}.example"; then
            mv "${apache_plugin_config}.example" "${apache_plugin_config}"
        fi
        if [[ -n "${APACHE_STATUS_URI}" ]]; then
            yq eval -i ".plugins[0].config.apache.apache_mod_status_webservers[0].url = strenv(APACHE_STATUS_URI)" "${apache_plugin_config}"
        else
            echo "WARNING: variable APACHE_STATUS_URI needs to be set for Apache plugin"
        fi
    fi

    if [ "${SWISNAP_ENABLE_CRI}" = "true" ]; then
        cri_plugin_config="${TASK_AUTOLOAD_DIR}/task-cri.yaml"
        if check_if_plugin_supported CRI "${cri_plugin_config}.example"; then
            mv "${cri_plugin_config}.example" "${cri_plugin_config}"
        fi
    fi

    if [ "${SWISNAP_ENABLE_DOCKER}" = "true" ]; then
        docker_plugin_config="${TASK_AUTOLOAD_DIR}/task-docker.yaml"
        if check_if_plugin_supported Docker "${docker_plugin_config}.example"; then
            mv "${docker_plugin_config}.example" "${docker_plugin_config}"
            if [[ -n "${HOST_PROC}" ]]; then
                sed -i 's,#procfs: "/proc",procfs: "'"${HOST_PROC}"'",g' "${docker_plugin_config}"
            fi
        fi
    fi

    if [ "${SWISNAP_ENABLE_DOCKER_LOGS}" = "true" ] && [ -n "${SWISNAP_DOCKER_LOGS_CONTAINER_NAMES}" ]; then
        DOCKER_LOGS_CONFIG="${TASK_AUTOLOAD_DIR}/task-logs-docker.yaml"
        if check_if_plugin_supported "Docker Logs" "${DOCKER_LOGS_CONFIG}.example"; then
            mv "${DOCKER_LOGS_CONFIG}.example" "${DOCKER_LOGS_CONFIG}"
            yq eval -i 'del(.plugins[] | select(.plugin_name == "docker-logs").config.logs)' "${DOCKER_LOGS_CONFIG}"
            for cont_name in ${SWISNAP_DOCKER_LOGS_CONTAINER_NAMES}; do
                yq eval -i '.plugins[] |= select(.plugin_name == "docker-logs").config.logs += [{"filters": {"name": {"'"${cont_name}"'": true}}}]' "${DOCKER_LOGS_CONFIG}"
            done

            yq eval -i '.plugins[] | select(.plugin_name == "docker-logs").config.logs[].options.showstdout = true' "${DOCKER_LOGS_CONFIG}"
            yq eval -i '.plugins[] | select(.plugin_name == "docker-logs").config.logs[].options.showstderr = true' "${DOCKER_LOGS_CONFIG}"
            yq eval -i '.plugins[] | select(.plugin_name == "docker-logs").config.logs[].options.follow = true' "${DOCKER_LOGS_CONFIG}"
            yq eval -i '.plugins[] | select(.plugin_name == "docker-logs").config.logs[].options.tail = "all"' "${DOCKER_LOGS_CONFIG}"
            yq eval -i '.plugins[] | select(.plugin_name == "docker-logs").config.logs[].options.since = ""' "${DOCKER_LOGS_CONFIG}"
            yq eval -i '.plugins[] | select(.plugin_name == "docker-logs").config.logs[].options.since = "" | .plugins[] | select(.plugin_name == "docker-logs").config.logs[].options.since tag= "!!str"' "${DOCKER_LOGS_CONFIG}"
        fi
    fi

    if [ "${SWISNAP_ENABLE_ELASTICSEARCH}" = "true" ]; then
        elasticsearch_plugin_config="${TASK_AUTOLOAD_DIR}/task-elasticsearch.yaml"
        if check_if_plugin_supported Elasticsearch "${elasticsearch_plugin_config}.example"; then
            mv "${elasticsearch_plugin_config}.example" "${elasticsearch_plugin_config}"
        fi
    fi

    if [ "${SWISNAP_ENABLE_HAPROXY}" = "true" ]; then
        haproxy_plugin_config="${TASK_AUTOLOAD_DIR}/task-haproxy.yaml"
        if check_if_plugin_supported HAProxy "${haproxy_plugin_config}.example"; then
            mv "${haproxy_plugin_config}.example" "${haproxy_plugin_config}"
        fi
        if [[ -n "${HAPROXY_STATS_URI}" ]]; then
            yq eval -i ".plugins[0].config.haproxy.endpoints[0].url = strenv(HAPROXY_STATS_URI)" "${haproxy_plugin_config}"
        else
            echo "WARNING: variable HAPROXY_STATS_URI needs to be set for HAProxy plugin"
        fi
    fi

    if [ "${SWISNAP_ENABLE_KUBERNETES}" = "true" ]; then
        kubernetes_plugin_config="${TASK_AUTOLOAD_DIR}/task-kubernetes.yaml"
        if check_if_plugin_supported Kubernetes "${kubernetes_plugin_config}.example"; then
            mv "${kubernetes_plugin_config}.example" "${kubernetes_plugin_config}"
            if [ "${IN_CLUSTER}" = "true" ]; then
                enable_incluster "${kubernetes_plugin_config}"
            fi
        fi
    fi

    if [ "${SWISNAP_ENABLE_KUBERNETES_LOGS}" = "true" ]; then
        KUBERNETES_LOGS_CONFIG="${TASK_AUTOLOAD_DIR}/task-logs-k8s-events.yaml"
        if check_if_plugin_supported "Kubernetes Logs" "${KUBERNETES_LOGS_CONFIG}.example"; then
            mv "${KUBERNETES_LOGS_CONFIG}.example" "${KUBERNETES_LOGS_CONFIG}"
            yq eval -i '.plugins[] | select(.plugin_name == "k8s-events").config.incluster = true' "${KUBERNETES_LOGS_CONFIG}"
            yq eval -i '.plugins[] |= select(.plugin_name == "k8s-events").config.filters += [{"namespace": "default"}]' "${KUBERNETES_LOGS_CONFIG}"
            yq eval -i '.plugins[] | select(.plugin_name == "k8s-events").config.filters[].watch_only = true' "${KUBERNETES_LOGS_CONFIG}"
            yq eval -i '.plugins[] | select(.plugin_name == "k8s-events").config.filters[].options.fieldSelector = "type==Normal"' "${KUBERNETES_LOGS_CONFIG}"
        fi
    fi

    if [ "${SWISNAP_ENABLE_NGINX}" = "true" ]; then
        NGINX_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-nginx.yaml"
        if check_if_plugin_supported Nginx "${NGINX_CONFIG}.example"; then
            mv "${NGINX_CONFIG}.example" "${NGINX_CONFIG}"
            if [[ -n "${NGINX_STATUS_URI}" ]]; then
            yq eval -i 'del(.plugins[] | select(.plugin_name == "bridge").config.nginx.urls)' "${NGINX_CONFIG}"
               for nginx_uri in ${NGINX_STATUS_URI}; do
                   yq eval -i '.plugins[] |= select(.plugin_name == "bridge").config.nginx.urls += ["'"${nginx_uri}"'"]' "${NGINX_CONFIG}"
               done
            else
                echo "WARNING: NGINX_STATUS_URI var was not set for Nginx plugin"
            fi
        fi
    fi

    if [ "${SWISNAP_ENABLE_NGINX_PLUS}" = "true" ]; then
        NGINX_PLUS_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-nginx_plus.yaml"
        if check_if_plugin_supported "Nginx Plus" "${NGINX_PLUS_CONFIG}.example"; then
            mv "${NGINX_PLUS_CONFIG}.example" "${NGINX_PLUS_CONFIG}"
            if [[ -n "${NGINX_PLUS_STATUS_URI}" ]]; then
            yq eval -i 'del(.plugins[] | select(.plugin_name == "bridge").config.nginx_plus.urls)' "${NGINX_PLUS_CONFIG}"
               for nginx_plus_uri in ${NGINX_PLUS_STATUS_URI}; do
                yq eval -i '.plugins[] |= select(.plugin_name == "bridge").config.nginx_plus.urls += ["'"${nginx_plus_uri}"'"]' "${NGINX_PLUS_CONFIG}"
               done
            else
                echo "WARNING: NGINX_PLUS_STATUS_URI var was not set for Nginx Plus plugin"
            fi
        fi
    fi

    if [ "${SWISNAP_ENABLE_NGINX_PLUS_API}" = "true" ]; then
        NGINX_PLUS_API_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-nginx_plus_api.yaml"
        if check_if_plugin_supported "Nginx Plus Api" "${NGINX_PLUS_API_CONFIG}.example"; then
            mv "${NGINX_PLUS_API_CONFIG}.example" "${NGINX_PLUS_API_CONFIG}"
            if [[ -n "${NGINX_PLUS_API_URI}" ]]; then
            yq eval -i 'del(.plugins[] | select(.plugin_name == "bridge").config.nginx_plus_api.urls)' "${NGINX_PLUS_API_CONFIG}"
               for nginx_plus_uri in ${NGINX_PLUS_API_URI}; do
                yq eval -i '.plugins[] |= select(.plugin_name == "bridge").config.nginx_plus_api.urls += ["'"${nginx_plus_uri}"'"]' "${NGINX_PLUS_API_CONFIG}"
               done
            else
                echo "WARNING: NGINX_PLUS_API_URI var was not set for Nginx Plus Api plugin"
            fi
        fi
    fi

    if [ "${SWISNAP_ENABLE_MESOS}" = "true" ]; then
        if check_if_plugin_supported Mesos "${PLUGINS_DIR}/mesos.yaml.example"; then
            mv "${PLUGINS_DIR}/mesos.yaml.example" "${PLUGINS_DIR}/mesos.yaml"
        fi
    fi

    if [ "${SWISNAP_ENABLE_MONGODB}" = "true" ]; then
        if check_if_plugin_supported MongoDB "${PLUGINS_DIR}/mongodb.yaml.example"; then
            mv "${PLUGINS_DIR}/mongodb.yaml.example" "${PLUGINS_DIR}/mongodb.yaml"
        fi
    fi

    if [ "${SWISNAP_ENABLE_MYSQL}" = "true" ]; then
        if check_if_plugin_supported MySQL "${PLUGINS_DIR}/mysql.yaml.example"; then
            mv "${PLUGINS_DIR}/mysql.yaml.example" "${PLUGINS_DIR}/mysql.yaml"
            if [[ -n "${MYSQL_USER}" && -n "${MYSQL_HOST}" && -n "${MYSQL_PORT}" ]]; then
                connection_string="${MYSQL_USER}:${MYSQL_PASS}@tcp(${MYSQL_HOST}:${MYSQL_PORT})/"
                yq eval -i ".collector.mysql.all.mysql_connection_string = \"$connection_string\"" "${PLUGINS_DIR}/mysql.yaml"                
            else
                echo "WARNING: all: MYSQL_USER, MYSQL_HOST, MYSQL_PORT variables needs to be set for MySQL plugin"
            fi
        fi
    fi

    if [ "${SWISNAP_ENABLE_ORACLEDB}" = "true" ]; then
        oracledb_plugin_config="${TASK_AUTOLOAD_DIR}/task-oracledb.yaml"
        if check_if_plugin_supported OracleDB "${oracledb_plugin_config}.example"; then
            mv "${oracledb_plugin_config}.example" "${oracledb_plugin_config}"
            if [[ -n "${ORACLEDB_USER}" ]] && [[ -n "${ORACLEDB_PASS}" ]] && [[ -n "${ORACLEDB_HOST}" ]]  && [[ -n "${ORACLEDB_PORT}" ]]&& [[ -n "${ORACLEDB_SERVICE_NAME}" ]]; then
                yq eval -i '.plugins[0].config.oracledb.connection_strings[0] = "oracle://'"${ORACLEDB_USER}:${ORACLEDB_PASS}@${ORACLEDB_HOST}:${ORACLEDB_PORT}/${ORACLEDB_SERVICE_NAME}"'"' "${oracledb_plugin_config}"                
            else
                echo "WARNING: all: ORACLEDB_USER, ORACLEDB_PASS, ORACLEDB_HOST, ORACLEDB_PORT, ORACLEDB_SERVICE_NAME variables needs to be set for OracleDB plugin"
            fi
        fi
    fi

    if [ "${SWISNAP_ENABLE_POSTGRESQL}" = "true" ]; then
        POSTGRES_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-postgresql.yaml"
        if check_if_plugin_supported "PostgreSQL" "${POSTGRES_CONFIG}.example"; then
            mv "${POSTGRES_CONFIG}.example" "${POSTGRES_CONFIG}"
            if [[ -n "${POSTGRES_ADDRESS}" ]]; then
                yq eval -i '.plugins[] |= select(.plugin_name == "bridge").config.postgresql.address = strenv(POSTGRES_ADDRESS)' "${POSTGRES_CONFIG}"
            else
                echo "WARNING: POSTGRES_ADDRESS var was not set for Postgres plugin."
            fi
        fi
    fi

    if [ "${SWISNAP_ENABLE_PROMETHEUS}" = "true" ]; then
        PROMETHEUS_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-prometheus.yaml"
        if check_if_plugin_supported "Prometheus" "${PROMETHEUS_CONFIG}.example"; then
            mv "${PROMETHEUS_CONFIG}.example" "${PROMETHEUS_CONFIG}"
            yq eval -i '.plugins[0].config.prometheus.monitor_kubernetes_pods = true' "${PROMETHEUS_CONFIG}"
            yq eval -i 'del(.plugins[0].config.prometheus.urls)' "${PROMETHEUS_CONFIG}"
        fi
    fi

    if [ "${SWISNAP_ENABLE_RABBITMQ}" = "true" ]; then
        if check_if_plugin_supported "RabbitMQ" "${PLUGINS_DIR}/rabbitmq.yaml.example"; then
            mv "${PLUGINS_DIR}/rabbitmq.yaml.example" "${PLUGINS_DIR}/rabbitmq.yaml"
        fi
    fi

    if [ "${SWISNAP_ENABLE_REDIS}" = "true" ]; then
        REDIS_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-redis.yaml"
        if check_if_plugin_supported "Redis" "${REDIS_CONFIG}.example"; then
            mv "${REDIS_CONFIG}.example" "${REDIS_CONFIG}"
            if [[ -n "${REDIS_SERVERS}" ]]; then
                yq eval -i 'del(.plugins[] | select(.plugin_name == "bridge").config.redis.servers)' "${REDIS_CONFIG}"
                for redis_server in ${REDIS_SERVERS}; do
                    yq eval -i '.plugins[] |= select(.plugin_name == "bridge").config.redis.servers += ["'"${redis_server}"'"]' "${REDIS_CONFIG}"
                done
            else
                echo "WARNING: REDIS_SERVERS var was not set for Redis plugin."
            fi
        fi
    fi

    if [ "${SWISNAP_ENABLE_SOCKET_LISTENER}" = "true" ]; then
        SOCKET_LISTENER_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-socket_listener.yaml"
        if check_if_plugin_supported "Socket Listener" "${SOCKET_LISTENER_CONFIG}"; then
            mv "${SOCKET_LISTENER_CONFIG}.example" "${SOCKET_LISTENER_CONFIG}"
            if [[ -n "${SOCKET_SERVICE_ADDRESS}" ]] && [[ -n "${SOCKET_DATA_FORMAT}" ]]; then
                echo "INFO: setting service_address for Socket Listener plugin to ${SOCKET_SERVICE_ADDRESS} and data format to ${SOCKET_DATA_FORMAT}"
                yq eval -i '.plugins[] |= select(.plugin_name == "bridge-stream").config.socket_listener.service_address = "'"${SOCKET_SERVICE_ADDRESS}"'"' "${SOCKET_LISTENER_CONFIG}"
                yq eval -i '.plugins[] |= select(.plugin_name == "bridge-stream").config.socket_listener.data_format = "'"${SOCKET_DATA_FORMAT}"'"' "${SOCKET_LISTENER_CONFIG}"
            else
                echo "WARNING: both SOCKET_SERVICE_ADDRESS and SOCKET_DATA_FORMAT needs to be set for socket listener plugin"
            fi
        fi
    fi

    if [ "${SWISNAP_ENABLE_STATSD}" = "true" ]; then
        if check_if_plugin_supported Statsd "${TASK_AUTOLOAD_DIR}/task-bridge-statsd.yaml.example"; then
            mv "${TASK_AUTOLOAD_DIR}/task-bridge-statsd.yaml.example" "${TASK_AUTOLOAD_DIR}/task-bridge-statsd.yaml"
        fi
    fi

    if [ "${SWISNAP_ENABLE_ZOOKEEPER}" = "true" ]; then
        if check_if_plugin_supported Zookeeper "${TASK_AUTOLOAD_DIR}/task-bridge-zookeeper.yaml.example"; then
            mv "${TASK_AUTOLOAD_DIR}/task-bridge-zookeeper.yaml.example" "${TASK_AUTOLOAD_DIR}/task-bridge-zookeeper.yaml"
        fi
    fi

    if [ "${SWISNAP_DISABLE_HOSTAGENT}" = "true" ]; then
        rm "${TASK_AUTOLOAD_DIR}/task-aosystem.yaml"
    fi

    if [ "${SWISNAP_DISABLE_PROCESSES}" = "true" ]; then
        rm "${TASK_AUTOLOAD_DIR}/task-processes.yaml"
    fi

}

# Function provide possibilty to modify snap config files during container startup. Customizing script
# have to be mounted in /tmp in the container. Script itself may for example check and use some 
# attributes of the container that are unknown prior to starting it.

run_plugins_customizations() {
    if [[ "${SWISNAP_CUSTOMIZE_ELASTICSEARCH}" == "true" ]] && [ -f "/tmp/customize_elasticsearch.sh" ]; then
        bash /tmp/customize_elasticsearch.sh
    fi

    if [[ "${SWISNAP_CUSTOMIZE_PUBLISHER_APPOPTICS}" == "true" ]] && [ -f "/tmp/customize_publisher_appoptics.sh" ]; then
        bash /tmp/customize_publisher_appoptics.sh
    fi
}

set_custom_tags() {
    if [ -n "${APPOPTICS_CUSTOM_TAGS}" ]; then
        local IFS=","
        for TAG in ${APPOPTICS_CUSTOM_TAGS}; do
            KEY=${TAG%%=*}
            VALUE=${TAG##*=}
            yq eval -i '.control.tags."/".["'"${KEY}"'"] = "'"${VALUE}"'"' "${CONFIG_FILE}"
        done
    fi
}

check_if_plugin_supported() {
    local plugin="${1}"
    local plugin_config="${2}"
    if [[ ! -f "${plugin_config}" ]]; then
        echo "WARNING. SolarWinds Snap Agent ${plugin} integration not supported. Please contact technicalsupport@solarwinds.com"
        return 1
    fi
    return 0
}

main() {
    swisnap_config_setup
    run_plugins_with_default_configs
    run_plugins_customizations
    set_custom_tags
    exec "${SWISNAP_HOME}/sbin/swisnapd" --config "${CONFIG_FILE}" "${FLAGS[@]}"
}

main
