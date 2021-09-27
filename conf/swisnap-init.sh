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

    # Use APPOPTICS_HOSTNAME as hostname_alias
    if [ -n "${APPOPTICS_HOSTNAME}" ]; then
        yq w -i "${PUBLISHER_APPOPTICS_CONFIG}" v1.publisher.publisher-appoptics.all.hostname_alias "${APPOPTICS_HOSTNAME}"
        yq w -i "${PUBLISHER_APPOPTICS_CONFIG}" v2.publisher.publisher-appoptics.all.endpoint.hostname_alias "${APPOPTICS_HOSTNAME}"
        yq w -i "${PUBLISHER_PROCESSES_CONFIG}" v2.publisher.publisher-processes.all.endpoint.hostname_alias "${APPOPTICS_HOSTNAME}"
    fi

    if [ -n "${LOG_LEVEL}" ]; then
        yq w -i $CONFIG_FILE log_level "${LOG_LEVEL}"
    fi

    if [ "${SWISNAP_SECURE}" = true ]; then
        FLAGS=("--keyring-paths" "${SWISNAP_HOME}/.gnupg/")
    else
        yq w -i ${CONFIG_FILE} control.plugin_trust_level 0
    fi

    yq w -i ${CONFIG_FILE} log_path "${LOG_PATH:-/proc/self/fd/1}"
    yq w -i ${CONFIG_FILE} restapi.addr "tcp://0.0.0.0:21413"

    # Logs Publishers releated configs
    if [ -n "${LOGGLY_TOKEN}" ] && [ "${LOGGLY_TOKEN}" != 'LOGGLY_TOKEN' ]; then
        LOGGLY_PUBL_TOKEN="${LOGGLY_TOKEN}"
    else
        LOGGLY_PUBL_TOKEN="${SWI_TOKEN}"
    fi

    yq w -i "${PUBLISHER_LOGS_CONFIG}" v2.publisher.loggly-http.all.token -- "${LOGGLY_PUBL_TOKEN}"
    yq w -i "${PUBLISHER_LOGS_CONFIG}" v2.publisher.loggly-http-bulk.all.token -- "${LOGGLY_PUBL_TOKEN}"
    yq w -i "${PUBLISHER_LOGS_CONFIG}" v2.publisher.loggly-syslog.all.token -- "${LOGGLY_PUBL_TOKEN}"

    if [ -n "${PAPERTRAIL_TOKEN}" ] && [ "${PAPERTRAIL_TOKEN}" != 'PAPERTRAIL_TOKEN' ]; then
        PAPERTRAIL_PUBL_TOKEN="${PAPERTRAIL_TOKEN}"
    else
        PAPERTRAIL_PUBL_TOKEN="${SWI_TOKEN}"
    fi

    yq w -i "${PUBLISHER_LOGS_CONFIG}" v2.publisher.swi-logs-http-bulk.all.token -- "${PAPERTRAIL_PUBL_TOKEN}"
    yq w -i "${PUBLISHER_LOGS_CONFIG}" v2.publisher.swi-logs-http.all.token -- "${PAPERTRAIL_PUBL_TOKEN}"

    if [ -n "${PAPERTRAIL_HOST}" ] && [ -n "${PAPERTRAIL_PORT}" ]; then
       yq w -i "${PUBLISHER_LOGS_CONFIG}" v2.publisher.papertrail-syslog.all.host "${PAPERTRAIL_HOST}"
       yq w -i "${PUBLISHER_LOGS_CONFIG}" v2.publisher.papertrail-syslog.all.port "${PAPERTRAIL_PORT}"
    fi


}

run_plugins_with_default_configs() {
    # Set to true to enable or disable specific plugins
    if [ "${SWISNAP_ENABLE_APACHE}" = "true" ]; then
        apache_plugin_config="${PLUGINS_DIR}/apache.yaml.example"
        check_if_plugin_supported Apache "${apache_plugin_config}"
        mv "${apache_plugin_config}" "${PLUGINS_DIR}/apache.yaml"
    fi

    if [ "${SWISNAP_ENABLE_DOCKER}" = "true" ]; then
        docker_plugin_config="${PLUGINS_DIR}/docker.yaml"
        check_if_plugin_supported Docker "${docker_plugin_config}.example"
        mv "${docker_plugin_config}.example" "${docker_plugin_config}"
        if [[ -n "${HOST_PROC}" ]]; then
            sed -i 's,procfs: "/proc",procfs: "'"${HOST_PROC}"'",g' "${docker_plugin_config}"
        fi
    fi

    if [ "${SWISNAP_ENABLE_DOCKER_LOGS}" = "true" ] && [ -n "${SWISNAP_DOCKER_LOGS_CONTAINER_NAMES}" ]; then
        DOCKER_LOGS_CONFIG="${TASK_AUTOLOAD_DIR}/task-logs-docker.yaml"
        check_if_plugin_supported "Docker Logs" "${DOCKER_LOGS_CONFIG}.example"
        mv "${DOCKER_LOGS_CONFIG}.example" "${DOCKER_LOGS_CONFIG}"
        yq d -i "${DOCKER_LOGS_CONFIG}" 'plugins.(plugin_name==docker-logs).config.logs'
        for cont_name in ${SWISNAP_DOCKER_LOGS_CONTAINER_NAMES}; do
            yq w -i "${DOCKER_LOGS_CONFIG}" "plugins.(plugin_name==docker-logs).config.logs[+].filters.name.${cont_name}" true
        done

        yq w -i "${DOCKER_LOGS_CONFIG}" 'plugins.(plugin_name==docker-logs).config.logs[*].options.showstdout' true
        yq w -i "${DOCKER_LOGS_CONFIG}" 'plugins.(plugin_name==docker-logs).config.logs[*].options.showstderr' true
        yq w -i "${DOCKER_LOGS_CONFIG}" 'plugins.(plugin_name==docker-logs).config.logs[*].options.follow' true
        yq w -i "${DOCKER_LOGS_CONFIG}" 'plugins.(plugin_name==docker-logs).config.logs[*].options.tail' all
        yq w -i "${DOCKER_LOGS_CONFIG}" 'plugins.(plugin_name==docker-logs).config.logs[*].options.since' --tag '!!str' ""
    fi


    if [ "${SWISNAP_ENABLE_ELASTICSEARCH}" = "true" ]; then
        check_if_plugin_supported Elasticsearch "${PLUGINS_DIR}/elasticsearch.yaml.example"
        mv "${PLUGINS_DIR}/elasticsearch.yaml.example" "${PLUGINS_DIR}/elasticsearch.yaml"
    fi

    if [ "${SWISNAP_ENABLE_KUBERNETES}" = "true" ]; then
        check_if_plugin_supported Kubernetes "${PLUGINS_DIR}/kubernetes.yaml.example" 
        mv "${PLUGINS_DIR}/kubernetes.yaml.example" "${PLUGINS_DIR}/kubernetes.yaml"
    fi

    if [ "${SWISNAP_ENABLE_KUBERNETES_LOGS}" = "true" ]; then
        KUBERNETES_LOGS_CONFIG="${TASK_AUTOLOAD_DIR}/task-logs-k8s-events.yaml"
        check_if_plugin_supported "Kubernetes Logs" "${KUBERNETES_LOGS_CONFIG}.example"
        mv "${KUBERNETES_LOGS_CONFIG}.example" "${KUBERNETES_LOGS_CONFIG}"
        yq w -i "${KUBERNETES_LOGS_CONFIG}" 'plugins.(plugin_name==k8s-events).config.incluster' 'true'
        yq w -i "${KUBERNETES_LOGS_CONFIG}" 'plugins.(plugin_name==k8s-events).config.filters[+].namespace' 'default'
        yq w -i "${KUBERNETES_LOGS_CONFIG}" 'plugins.(plugin_name==k8s-events).config.filters[*].watch_only' 'true'
        yq w -i "${KUBERNETES_LOGS_CONFIG}" 'plugins.(plugin_name==k8s-events).config.filters[*].options.fieldSelector' 'type==Normal'
    fi

    if [ "${SWISNAP_ENABLE_NGINX}" = "true" ]; then
        NGINX_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-nginx.yaml"
        check_if_plugin_supported Nginx "${NGINX_CONFIG}.example"
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
        check_if_plugin_supported "Nginx Plus" "${NGINX_PLUS_CONFIG}.example"
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
        check_if_plugin_supported "Nginx Plus Api" "${NGINX_PLUS_API_CONFIG}.example"
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
        check_if_plugin_supported Mesos "${PLUGINS_DIR}/mesos.yaml.example"
        mv "${PLUGINS_DIR}/mesos.yaml.example" "${PLUGINS_DIR}/mesos.yaml"
    fi

    if [ "${SWISNAP_ENABLE_MONGODB}" = "true" ]; then
        check_if_plugin_supported MongoDB "${PLUGINS_DIR}/mongodb.yaml.example"
        mv "${PLUGINS_DIR}/mongodb.yaml.example" "${PLUGINS_DIR}/mongodb.yaml"
    fi

    if [ "${SWISNAP_ENABLE_MYSQL}" = "true" ]; then
        check_if_plugin_supported MySQL "${PLUGINS_DIR}/mysql.yaml.example"
        mv "${PLUGINS_DIR}/mysql.yaml.example" "${PLUGINS_DIR}/mysql.yaml"
        if [[ -n "${MYSQL_USER}" && -n "${MYSQL_HOST}" && -n "${MYSQL_PORT}" ]]; then
            yq w -i "${PLUGINS_DIR}/mysql.yaml" collector.mysql.all.mysql_connection_string "\"${MYSQL_USER}:${MYSQL_PASS}@tcp\(${MYSQL_HOST}:${MYSQL_PORT}\)\/\""
        else
            echo "WARNING: all: MYSQL_USER, MYSQL_HOST, MYSQL_PORT variables needs to be set for MySQL plugin"
        fi
    fi

    if [ "${SWISNAP_ENABLE_POSTGRESQL}" = "true" ]; then
        POSTGRES_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-postgresql.yaml"
        check_if_plugin_supported "PostgreSQL" "${POSTGRES_CONFIG}.example"
        mv "${POSTGRES_CONFIG}.example" "${POSTGRES_CONFIG}"
        if [[ -n "${POSTGRES_ADDRESS}" ]]; then
            yq w -i "${POSTGRES_CONFIG}" 'plugins.(plugin_name==bridge).config.postgresql.address' "${POSTGRES_ADDRESS}"
        else
            echo "WARNING: POSTGRES_ADDRESS var was not set for Postgres plugin."
        fi
    fi

    if [ "${SWISNAP_ENABLE_PROMETHEUS}" = "true" ]; then
        PROMETHEUS_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-prometheus.yaml"
        check_if_plugin_supported "Prometheus" ${PROMETHEUS_CONFIG}.example"
        mv "${PROMETHEUS_CONFIG}.example" "${PROMETHEUS_CONFIG}"
        yq w -i "${PROMETHEUS_CONFIG}" plugins[0].config.prometheus.monitor_kubernetes_pods true
        yq d -i "${PROMETHEUS_CONFIG}" plugins[0].config.prometheus.urls
    fi

    if [ "${SWISNAP_ENABLE_RABBITMQ}" = "true" ]; then
        check_if_plugin_supported "RabbitMQ" "${PLUGINS_DIR}/rabbitmq.yaml.example"
        mv "${PLUGINS_DIR}/rabbitmq.yaml.example" "${PLUGINS_DIR}/rabbitmq.yaml"
    fi

    if [ "${SWISNAP_ENABLE_REDIS}" = "true" ]; then
        REDIS_CONFIG="${TASK_AUTOLOAD_DIR}/task-bridge-redis.yaml"
        check_if_plugin_supported "Redis" "${REDIS_CONFIG}.example"
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
        check_if_plugin_supported "Socket Listener" "${SOCKET_LISTENER_CONFIG}" 
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
        check_if_plugin_supported Statsd "${TASK_AUTOLOAD_DIR}/task-bridge-statsd.yaml.example"
        mv "${TASK_AUTOLOAD_DIR}/task-bridge-statsd.yaml.example" "${TASK_AUTOLOAD_DIR}/task-bridge-statsd.yaml"
    fi

    if [ "${SWISNAP_ENABLE_ZOOKEEPER}" = "true" ]; then
        check_if_plugin_supported Zookeeper "${TASK_AUTOLOAD_DIR}/task-bridge-zookeeper.yaml.example"
        mv "${TASK_AUTOLOAD_DIR}/task-bridge-zookeeper.yaml.example" "${TASK_AUTOLOAD_DIR}/task-bridge-zookeeper.yaml"
    fi

    if [ "${SWISNAP_DISABLE_HOSTAGENT}" = "true" ]; then
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

check_if_plugin_supported() {
    local plugin="${1}"
    local plugin_config="${2}"
    if [[ ! -f "${plugin_config}" ]]; then
        echo "WARNING. SolarWinds Snap Agent ${plugin} integration not supported. Please contact technicalsupport@solarwinds.com"
    fi
}

main() {
    swisnap_config_setup
    run_plugins_with_default_configs
    set_custom_tags
    exec "${SWISNAP_HOME}/sbin/swisnapd" --config "${CONFIG_FILE}" "${FLAGS[@]}"
}

main
