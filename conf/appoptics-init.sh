#!/bin/bash
# chris.rust@solarwinds.com - 20180227
set -e

APPOPTICS_HOME='/opt/appoptics/'
CONFIG_FILE="${APPOPTICS_HOME}/etc/config.yaml"
TMP_FILE="${APPOPTICS_HOME}/etc/config.yaml.tmp"

# APPOPTICS_TOKEN is required
if [ -n "${APPOPTICS_TOKEN}" ]; then
    cat $CONFIG_FILE |  yq ".control.plugins.publisher.\"publisher-appoptics\".all.token = \"$APPOPTICS_TOKEN\"" --yaml-output > $TMP_FILE
    cp $TMP_FILE $CONFIG_FILE
else
    echo "Please set APPOPTICS_TOKEN."
    exit 1
fi

# Translate LOG_LEVEL to snapteld log_level 1-5
if [ -n "${LOG_LEVEL}" ]; then
    shopt -s nocasematch           # turn on case-insensitive matching for case stmt
    case $LOG_LEVEL in
        debug) loglevel=1;;
        info) loglevel=2;;
        warn|warning) loglevel=3;;
        error) loglevel=4;;
        fatal) loglevel=5;;
        *) loglevel=3;;
    esac
    shopt -u nocasematch
    echo
    cat $CONFIG_FILE |  yq ".log_level = ${loglevel}" --yaml-output > $TMP_FILE
    cp $TMP_FILE $CONFIG_FILE
fi

# Use APPOPTICS_HOSTNAME as hostname_alias
if [ -n "$APPOPTICS_HOSTNAME" ]; then
    cat $CONFIG_FILE |  yq ".control.plugins.publisher.\"publisher-appoptics\".all.hostname_alias = \"${APPOPTICS_HOSTNAME}\"" --yaml-output > $TMP_FILE
    cp $TMP_FILE $CONFIG_FILE
fi

# Set to true to enable or disable specific plugins
PLUGINS_DIR="${APPOPTICS_HOME}/etc/plugins.d/"
if [ "$APPOPTICS_ENABLE_APACHE" = "true" ]; then
    mv ${PLUGINS_DIR}/apache.yaml.example ${PLUGINS_DIR}/apache.yaml
fi

if [ "$APPOPTICS_ENABLE_DOCKER" = "true" ]; then
    mv ${PLUGINS_DIR}/docker.yaml.example ${PLUGINS_DIR}/docker.yaml
fi

if [ "$APPOPTICS_ENABLE_ELASTICSEARCH" = "true" ]; then
    mv ${PLUGINS_DIR}/elasticsearch.yaml.example ${PLUGINS_DIR}/elasticsearch.yaml
fi

if [ "$APPOPTICS_ENABLE_KUBERNETES" = "true" ]; then
    mv ${PLUGINS_DIR}/kubernetes.yaml.example ${PLUGINS_DIR}/kubernetes.yaml
fi

if [ "$APPOPTICS_ENABLE_MESOS" = "true" ]; then
    mv ${PLUGINS_DIR}/mesos.yaml.example ${PLUGINS_DIR}/mesos.yaml
fi

if [ "$APPOPTICS_ENABLE_MONGODB" = "true" ]; then
    mv ${PLUGINS_DIR}/mongodb.yaml.example ${PLUGINS_DIR}/mongodb.yaml
fi

if [ "$APPOPTICS_ENABLE_MYSQL" = "true" ]; then
    mv ${PLUGINS_DIR}/mysql.yaml.example ${PLUGINS_DIR}/mysql.yaml
    if [[ -n ${MYSQL_USER} && -n ${MYSQL_HOST} && -n ${MYSQL_PORT} ]]; then
        cat ${PLUGINS_DIR}/mysql.yaml.example | yq ".collector.mysql.all.mysql_connection_string = \"$MYSQL_USER:$MYSQL_PASS@tcp($MYSQL_HOST:$MYSQL_PORT)\/\"" > $TMP_FILE
        cp $TMP_FILE $CONFIG_FILE
     fi
fi

if [ "$APPOPTICS_ENABLE_RABBITMQ" = "true" ]; then
    mv ${PLUGINS_DIR}/rabbitmq.yaml.example ${PLUGINS_DIR}/rabbitmq.yaml
fi

if [ "$APPOPTICS_ENABLE_ZOOKEEPER" = "true" ]; then
    mv ${PLUGINS_DIR}/zookeeper.yaml.example ${PLUGINS_DIR}/zookeeper.yaml
fi

if [ "$APPOPTICS_DISABLE_HOSTAGENT" = "true" ]; then
    rm ${APPOPTICS_HOME}/autoload/snap-plugin-collector-aosystem
    rm ${APPOPTICS_HOME}/autoload/task-aosystem-warmup.yaml
    rm ${APPOPTICS_HOME}/autoload/task-aosystem.yaml
fi

if [ -n "$APPOPTICS_CUSTOM_TAGS" ]; then
    IFS=","
    for TAG in $APPOPTICS_CUSTOM_TAGS
    do
       KEY=${TAG%%=*}
       VALUE=${TAG##*=}
       cat $CONFIG_FILE | yq ".control.tags.\"/\"[\"${KEY}\"] = \"${VALUE}\"" --yaml-output > $TMP_FILE
       cp $TMP_FILE $CONFIG_FILE
    done
fi

# Cleanup $TMP_FILE
[ -f "$TMP_FILE" ] && rm $TMP_FILE

exec ${APPOPTICS_HOME}/sbin/snapteld --config $CONFIG_FILE
