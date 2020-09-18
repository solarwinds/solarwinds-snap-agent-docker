#!/bin/bash
# chris.rust@solarwinds.com - 20180227
set -e

SWISNAP_HOME="/opt/SolarWinds/Snap/"
PLUGINS_DIR="${SWISNAP_HOME}/etc/plugins.d"
TASK_AUTOLOAD_DIR="${SWISNAP_HOME}/etc/tasks-autoload.d"
CONFIG_FILE="${SWISNAP_HOME}/etc/config.yaml"
PUBLISHER_PROCESSES_CONFIG="${PLUGINS_DIR}/publisher-processes.yaml"
PUBLISHER_APPOPTICS_CONFIG="${PLUGINS_DIR}/publisher-appoptics.yaml"

swisnap_config_setup() {
    # SOLARWINDS_TOKEN is required. Please note, that APPOPTICS_TOKEN is left for preserving backward compatibility
    if [ -n "${SOLARWINDS_TOKEN}" ] && [ "${SOLARWINDS_TOKEN}" != 'SOLARWINDS_TOKEN' ]; then
        SWI_TOKEN="${SOLARWINDS_TOKEN}"
    elif [ -n "${APPOPTICS_TOKEN}" ] && [ "${APPOPTICS_TOKEN}" != 'APPOPTICS_TOKEN' ]; then
        SWI_TOKEN="${APPOPTICS_TOKEN}"
    else
        echo "Please set SOLARWINDS_TOKEN. Exiting"
        exit 1
    fi

    yq w -i "${PUBLISHER_APPOPTICS_CONFIG}" v1.publisher.publisher-appoptics.all.token -- "${SWI_TOKEN}"
    yq w -i "${PUBLISHER_APPOPTICS_CONFIG}" v2.publisher.publisher-appoptics.all.endpoint.token -- "${SWI_TOKEN}"
    yq w -i "${PUBLISHER_PROCESSES_CONFIG}" v2.publisher.publisher-processes.all.endpoint.token -- "${SWI_TOKEN}"

    yq w -i ${CONFIG_FILE} log_path "${LOG_PATH:-/proc/self/fd/1}"
    yq w -i ${CONFIG_FILE} restapi.addr 0.0.0.0

    if [ -n "${LOG_LEVEL}" ]; then
        yq w -i $CONFIG_FILE log_level "${LOG_LEVEL}"
    fi

    if [ "${SWISNAP_SECURE}" = true ]; then
        yq w -i ${CONFIG_FILE} control.plugin_trust_level 1
        FLAGS=("--keyring-paths" "${SWISNAP_HOME}/.gnupg/")
    fi

    # Use APPOPTICS_HOSTNAME as hostname_alias
    if [ -n "${APPOPTICS_HOSTNAME}" ]; then
        yq w -i "${CONFIG_FILE}" control.plugins.publisher.publisher-appoptics.all.hostname_alias "${APPOPTICS_HOSTNAME}"
    fi
}

run_plugins_with_default_configs() {
    # Set to true to enable or disable specific plugins
    if [ "${SWISNAP_ENABLE_APACHE}" = "true" ]; then
        mv "${PLUGINS_DIR}/apache.yaml.example" "${PLUGINS_DIR}/apache.yaml"
    fi

    if [ "$SWISNAP_ENABLE_DOCKER" = "true" ]; then
        mv "${PLUGINS_DIR}/docker.yaml.example" "${PLUGINS_DIR}/docker.yaml"
        if [[ -n "${HOST_PROC}" ]]; then
            sed -i 's,procfs: "/proc",procfs: "'"${HOST_PROC}"'",g' "${PLUGINS_DIR}/docker.yaml"
        fi
    fi

    if [ "${SWISNAP_ENABLE_ELASTICSEARCH}" = "true" ]; then
        mv "${PLUGINS_DIR}/elasticsearch.yaml.example" "${PLUGINS_DIR}/elasticsearch.yaml"
    fi

    if [ "${SWISNAP_ENABLE_KUBERNETES}" = "true" ]; then
        mv "${PLUGINS_DIR}/kubernetes.yaml.example" "${PLUGINS_DIR}/kubernetes.yaml"
    fi

    if [ "${SWISNAP_ENABLE_NGINX}" = "true" ]; then
        NGINX_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-nginx.yaml"
        mv "${NGINX_CONFIG}.example" "${NGINX_CONFIG}"
        if [[ -n "${NGINX_STATUS_URI}" ]]; then
           yq d -i "${NGINX_CONFIG}" 'plugins.(plugin_name==bridge).config.nginx.urls'
           for nginx_uri in ${NGINX_STATUS_URI}; do
               yq w -i "${NGINX_CONFIG}" 'plugins.(plugin_name==bridge).config.nginx.urls[+]' "${nginx_uri}"
           done
        else
            echo "WARNING: NGINX_STATUS_URI var was not set for Nginx plugin"
        fi
    fi

    if [ "${SWISNAP_ENABLE_NGINX_PLUS}" = "true" ]; then
        NGINX_PLUS_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-nginx_plus.yaml"
        mv "${NGINX_PLUS_CONFIG}.example" "${NGINX_PLUS_CONFIG}"
        if [[ -n "${NGINX_PLUS_STATUS_URI}" ]]; then
           yq d -i "${NGINX_PLUS_CONFIG}" 'plugins.(plugin_name==bridge).config.nginx_plus.urls'
           for nginx_plus_uri in ${NGINX_PLUS_STATUS_URI}; do
               yq w -i "${NGINX_PLUS_CONFIG}" 'plugins.(plugin_name==bridge).config.nginx_plus.urls[+]' "${nginx_plus_uri}"
           done
        else
            echo "WARNING: NGINX_PLUS_STATUS_URI var was not set for Nginx Plus plugin"
        fi
    fi

    if [ "${SWISNAP_ENABLE_NGINX_PLUS_API}" = "true" ]; then
        NGINX_PLUS_API_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-nginx_plus_api.yaml"
        mv "${NGINX_PLUS_API_CONFIG}.example" "${NGINX_PLUS_API_CONFIG}"
        if [[ -n "${NGINX_PLUS_API_URI}" ]]; then
           yq d -i "${NGINX_PLUS_API_CONFIG}" 'plugins.(plugin_name==bridge).config.nginx_plus_api.urls'
           for nginx_plus_uri in ${NGINX_PLUS_API_URI}; do
               yq w -i "${NGINX_PLUS_API_CONFIG}" 'plugins.(plugin_name==bridge).config.nginx_plus_api.urls[+]' "${nginx_plus_uri}"
           done
        else
            echo "WARNING: NGINX_PLUS_API_URI var was not set for Nginx Plus Api plugin"
        fi
    fi

    if [ "${SWISNAP_ENABLE_MESOS}" = "true" ]; then
        mv "${PLUGINS_DIR}/mesos.yaml.example" "${PLUGINS_DIR}/mesos.yaml"
    fi

    if [ "${SWISNAP_ENABLE_MONGODB}" = "true" ]; then
        mv "${PLUGINS_DIR}/mongodb.yaml.example" "${PLUGINS_DIR}/mongodb.yaml"
    fi

    if [ "${SWISNAP_ENABLE_MYSQL}" = "true" ]; then
        mv "${PLUGINS_DIR}/mysql.yaml.example" "${PLUGINS_DIR}/mysql.yaml"
        if [[ -n "${MYSQL_USER}" && -n "${MYSQL_HOST}" && -n "${MYSQL_PORT}" ]]; then
            yq w -i "${PLUGINS_DIR}/mysql.yaml" collector.mysql.all.mysql_connection_string "\"${MYSQL_USER}:${MYSQL_PASS}@tcp\(${MYSQL_HOST}:${MYSQL_PORT}\)\/\""
        else
            echo "WARNING: all: MYSQL_USER, MYSQL_HOST, MYSQL_PORT variables needs to be set for MySQL plugin"
        fi
    fi

    if [ "${SWISNAP_ENABLE_POSTGRESQL}" = "true" ]; then
        POSTGRES_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-postgresql.yaml"
        mv "${POSTGRES_CONFIG}.example" "${POSTGRES_CONFIG}"
        if [[ -n "${POSTGRES_ADDRESS}" ]]; then
            yq w -i "${POSTGRES_CONFIG}" 'plugins.(plugin_name==bridge).config.postgresql.address' "${POSTGRES_ADDRESS}"
        else
            echo "WARNING: POSTGRES_ADDRESS var was not set for Postgres plugin."
        fi
    fi

    if [ "${SWISNAP_ENABLE_PROMETHEUS}" = "true" ]; then
        PROMETHEUS_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-prometheus.yaml"
        mv "${PROMETHEUS_CONFIG}.example" "${PROMETHEUS_CONFIG}"
        yq w -i "${PROMETHEUS_CONFIG}" plugins[0].config.prometheus.monitor_kubernetes_pods true
        yq d -i "${PROMETHEUS_CONFIG}" plugins[0].config.prometheus.urls
    fi

    if [ "${SWISNAP_ENABLE_RABBITMQ}" = "true" ]; then
        mv "${PLUGINS_DIR}/rabbitmq.yaml.example" "${PLUGINS_DIR}/rabbitmq.yaml"
    fi

    if [ "${SWISNAP_ENABLE_REDIS}" = "true" ]; then
        REDIS_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-redis.yaml"
        mv "${REDIS_CONFIG}.example" "${REDIS_CONFIG}"
        if [[ -n "${REDIS_SERVERS}" ]]; then
            yq d -i "${REDIS_CONFIG}" 'plugins.(plugin_name==bridge).config.redis.servers'
            for redis_server in ${REDIS_SERVERS}; do
                yq w -i "${REDIS_CONFIG}" 'plugins.(plugin_name==bridge).config.redis.servers[+]' "${redis_server}"
            done
        else
            echo "WARNING: REDIS_SERVERS var was not set for Redis plugin."
        fi
    fi

    if [ "${SWISNAP_ENABLE_SOCKET_LISTENER}" = "true" ]; then
        SOCKET_LISTENER_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-socket_listener.yaml"
        mv "${SOCKET_LISTENER_CONFIG}.example" "${SOCKET_LISTENER_CONFIG}"
        if [[ -n "${SOCKET_SERVICE_ADDRESS}" ]] && [[ -n "${SOCKET_DATA_FORMAT}" ]]; then
            echo "INFO: setting service_address for Socket Listener plugin to ${SOCKET_SERVICE_ADDRESS} and data format to ${SOCKET_DATA_FORMAT}"
            yq w -i "${SOCKET_LISTENER_CONFIG}" 'plugins.(plugin_name==bridge-stream).config.socket_listener.service_address' "${SOCKET_SERVICE_ADDRESS}"
            yq w -i "${SOCKET_LISTENER_CONFIG}" 'plugins.(plugin_name==bridge-stream).config.socket_listener.data_format' "${SOCKET_DATA_FORMAT}"
        else
            echo "WARNING: both SOCKET_SERVICE_ADDRESS and SOCKET_DATA_FORMAT needs to be set for socket listener plugin"
        fi
    fi
    if [ "${SWISNAP_ENABLE_STATSD}" = "true" ]; then
        mv "${TASK_AUTOLOAD_DIR}/task-bridge-statsd.yaml.example" "${TASK_AUTOLOAD_DIR}/task-bridge-statsd.yaml"
    fi

    if [ "${SWISNAP_ENABLE_ZOOKEEPER}" = "true" ]; then
        mv "${TASK_AUTOLOAD_DIR}/task-bridge-zookeeper.yaml.example" "${TASK_AUTOLOAD_DIR}/task-bridge-zookeeper.yaml"
    fi

    if [ "${SWISNAP_DISABLE_HOSTAGENT}" = "true" ]; then
        rm "${TASK_AUTOLOAD_DIR}/task-aosystem-warmup.yaml"
        rm "${TASK_AUTOLOAD_DIR}/task-aosystem.yaml"
    fi

    if [ "${SWISNAP_DISABLE_PROCESSES}" = "true" ]; then
        rm "${TASK_AUTOLOAD_DIR}/task-processes.yaml"
    fi

}

set_custom_tags() {
    if [ -n "${APPOPTICS_CUSTOM_TAGS}" ]; then
        local IFS=","
        for TAG in ${APPOPTICS_CUSTOM_TAGS}; do
            KEY=${TAG%%=*}
            VALUE=${TAG##*=}
            yq w -i ${CONFIG_FILE} "control.tags./[${KEY}]" "${VALUE}"
        done
    fi
}

main() {
    swisnap_config_setup
    run_plugins_with_default_configs
    set_custom_tags
    exec "${SWISNAP_HOME}/sbin/swisnapd" --config "${CONFIG_FILE}" "${FLAGS[@]}"
}

main
