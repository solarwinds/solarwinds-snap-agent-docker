#!/bin/bash
# chris.rust@solarwinds.com - 20180227
set -e

SWISNAP_HOME='/opt/SolarWinds/Snap/'
CONFIG_FILE="${SWISNAP_HOME}/etc/config.yaml"

swisnap_config_setup() {
    # APPOPTICS_TOKEN is required
    if [ -z "${APPOPTICS_TOKEN}" ] || [ "${APPOPTICS_TOKEN}" = 'APPOPTICS_TOKEN' ]; then
        echo "Please set APPOPTICS_TOKEN."
        exit 1
    else
        yq w -i ${CONFIG_FILE} control.plugins.publisher.publisher-appoptics.all.token ${APPOPTICS_TOKEN}
        yq w -i ${CONFIG_FILE} control.plugins.publisher.publisher-processes.all.token ${APPOPTICS_TOKEN}
    fi

    yq d -i ${CONFIG_FILE} log_path
    yq w -i ${CONFIG_FILE} restapi.addr 0.0.0.0

    if [ -n "${LOG_LEVEL}" ]; then
        yq w -i $CONFIG_FILE log_level "${LOG_LEVEL}"
    fi

    if [ "${SWISNAP_SECURE}" = true ]; then
        yq w -i $CONFIG_FILE control.plugin_trust_level 1
        FLAGS="--keyring-paths ${SWISNAP_HOME}/.gnupg/"
    fi

    # Use APPOPTICS_HOSTNAME as hostname_alias
    if [ -n "${APPOPTICS_HOSTNAME}" ]; then
        yq w -i ${CONFIG_FILE} control.plugins.publisher.publisher-appoptics.all.hostname_alias ${APPOPTICS_HOSTNAME}
    fi
}

run_plugins_with_default_configs() {
    # Set to true to enable or disable specific plugins
    PLUGINS_DIR="${SWISNAP_HOME}/etc/plugins.d/"
    if [ "${SWISNAP_ENABLE_APACHE}" = "true" ]; then
        mv ${PLUGINS_DIR}/apache.yaml.example ${PLUGINS_DIR}/apache.yaml
    fi

    if [ "$SWISNAP_ENABLE_DOCKER" = "true" ]; then
        mv ${PLUGINS_DIR}/docker.yaml.example ${PLUGINS_DIR}/docker.yaml
        if [[ -n ${HOST_PROC} ]]; then
            sed -i 's,procfs: "/proc",procfs: "'${HOST_PROC}'",g' ${PLUGINS_DIR}/docker.yaml
        fi
    fi

    if [ "${SWISNAP_ENABLE_ELASTICSEARCH}" = "true" ]; then
        mv ${PLUGINS_DIR}/elasticsearch.yaml.example ${PLUGINS_DIR}/elasticsearch.yaml
    fi

    if [ "${SWISNAP_ENABLE_KUBERNETES}" = "true" ]; then
        mv ${PLUGINS_DIR}/kubernetes.yaml.example ${PLUGINS_DIR}/kubernetes.yaml
    fi

    if [ "${SWISNAP_ENABLE_MESOS}" = "true" ]; then
        mv ${PLUGINS_DIR}/mesos.yaml.example ${PLUGINS_DIR}/mesos.yaml
    fi

    if [ "${SWISNAP_ENABLE_MONGODB}" = "true" ]; then
        mv ${PLUGINS_DIR}/mongodb.yaml.example ${PLUGINS_DIR}/mongodb.yaml
    fi

    if [ "${SWISNAP_ENABLE_MYSQL}" = "true" ]; then
        mv ${PLUGINS_DIR}/mysql.yaml.example ${PLUGINS_DIR}/mysql.yaml
        if [[ -n ${MYSQL_USER} && -n ${MYSQL_HOST} && -n ${MYSQL_PORT} ]]; then
            yq w -i ${PLUGINS_DIR}/mysql.yaml collector.mysql.all.mysql_connection_string "\"${MYSQL_USER}:${MYSQL_PASS}@tcp(${MYSQL_HOST}:${MYSQL_PORT})\/\""
        fi
    fi

    if [ "${SWISNAP_ENABLE_RABBITMQ}" = "true" ]; then
        mv ${PLUGINS_DIR}/rabbitmq.yaml.example ${PLUGINS_DIR}/rabbitmq.yaml
    fi

    if [ "${SWISNAP_ENABLE_STATSD}" = "true" ]; then
        mv ${PLUGINS_DIR}/statsd.yaml.example ${PLUGINS_DIR}/statsd.yaml
    fi

    if [ "${SWISNAP_ENABLE_ZOOKEEPER}" = "true" ]; then
        mv ${PLUGINS_DIR}/zookeeper.yaml.example ${PLUGINS_DIR}/zookeeper.yaml
    fi

    if [ "${SWISNAP_DISABLE_HOSTAGENT}" = "true" ]; then
        rm ${SWISNAP_HOME}/autoload/snap-plugin-collector-aosystem
        rm ${SWISNAP_HOME}/autoload/task-aosystem-warmup.yaml
        rm ${SWISNAP_HOME}/autoload/task-aosystem.yaml
    fi

    if [ "${SWISNAP_DISABLE_PROCESSES}" = "true" ]; then
        rm ${SWISNAP_HOME}/autoload/snap-plugin-publisher-processes
        rm ${SWISNAP_HOME}/autoload/task-processes.yaml
    fi
}

set_custom_tags() {
    if [ -n "${APPOPTICS_CUSTOM_TAGS}" ]; then
        IFS=","
        for TAG in ${APPOPTICS_CUSTOM_TAGS}; do
            KEY=${TAG%%=*}
            VALUE=${TAG##*=}
            yq w -i ${CONFIG_FILE} "control.tags.\"/\"[\"${KEY}\"]" "\"${VALUE}\""
        done
    fi
}

main() {
    swisnap_config_setup
    run_plugins_with_default_configs
    set_custom_tags

    env | sort

    # shellcheck disable=SC2086
    exec ${SWISNAP_HOME}/sbin/swisnapd --config ${CONFIG_FILE} ${FLAGS} --log-path ""
}

main
