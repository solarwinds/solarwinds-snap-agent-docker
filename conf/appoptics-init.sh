#!/bin/bash
# chris.rust@solarwinds.com - 20180227
set -e

CONFIG_FILE='/opt/appoptics/etc/config.yaml'
TMP_FILE='/opt/appoptics/etc/config.yaml.tmp'

if [ -n "$APPOPTICS_NODE_NAME" ]; then
    sed "s/# hostname_alias: myhostname/hostname_alias: $APPOPTICS_NODE_NAME/" $CONFIG_FILE > $TMP_FILE
    cp $TMP_FILE $CONFIG_FILE
fi

exec /opt/appoptics/sbin/snapteld --config $CONFIG_FILE
