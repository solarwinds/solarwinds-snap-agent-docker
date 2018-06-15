#!/bin/bash
# chris.rust@solarwinds.com - 20180227
set -e

CONFIG_FILE='/opt/appoptics/etc/config.yaml'
TMP_FILE='/opt/appoptics/etc/config.yaml.tmp'

# APPOPTICS_TOKEN is required
if [ -n "${APPOPTICS_TOKEN}" ]; then
    sed "s/APPOPTICS_TOKEN/${APPOPTICS_TOKEN}/" $CONFIG_FILE > $TMP_FILE
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

    sed "s/^#log_level: 3/log_level: ${loglevel}/" $CONFIG_FILE > $TMP_FILE
    cp $TMP_FILE $CONFIG_FILE
fi

# Use APPOPTICS_HOSTNAME as hostname_alias
if [ -n "$APPOPTICS_HOSTNAME" ]; then
    sed "s/# hostname_alias: myhostname/hostname_alias: ${APPOPTICS_HOSTNAME}/" $CONFIG_FILE > $TMP_FILE
    cp $TMP_FILE $CONFIG_FILE
fi

# Set to true to enable or disable specific plugins
if [ "$APPOPTICS_ENABLE_DOCKER" = "true" ]; then
    mv /tmp/appoptics-configs/docker.yaml /opt/appoptics/etc/plugins.d/docker.yaml
fi

if [ "$APPOPTICS_ENABLE_KUBERNETES" = "true" ]; then
    mv /tmp/appoptics-configs/kubernetes.yaml /opt/appoptics/etc/plugins.d/kubernetes.yaml
fi

if [ "$APPOPTICS_ENABLE_ZOOKEEPER" = "true" ]; then
    mv /opt/appoptics/etc/plugins.d/zookeeper.yaml.example /opt/appoptics/etc/plugins.d/zookeeper.yaml
fi

if [ "$APPOPTICS_ENABLE_MYSQL" = "true" ]; then
    mv /opt/appoptics/etc/plugins.d/mysql.yaml.example /opt/appoptics/etc/plugins.d/mysql.yaml
    sed -i -e "s/root:admin\@tcp(mysql:3306)/$MYSQL_USER:$MYSQL_PASS\@tcp($MYSQL_HOST:$MYSQL_PORT)/" /opt/appoptics/etc/plugins.d/mysql.yaml
fi

if [ "$APPOPTICS_DISABLE_HOSTAGENT" = "true" ]; then
    rm /opt/appoptics/autoload/snap-plugin-collector-aosystem
    rm /opt/appoptics/autoload/task-aosystem-warmup.yaml
    rm /opt/appoptics/autoload/task-aosystem.yaml
fi

# Cleanup $TMP_FILE
[ -f "$TMP_FILE" ] && rm $TMP_FILE

exec /opt/appoptics/sbin/snapteld --config $CONFIG_FILE
