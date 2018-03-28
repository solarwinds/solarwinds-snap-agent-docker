#!/bin/bash
# chris.rust@solarwinds.com - 20180227
set -e

CONFIG_FILE='/opt/appoptics/etc/config.yaml'
TMP_FILE='/opt/appoptics/etc/config.yaml.tmp'

# If APPOPTICS_HOSTNAME is set in env, then use it as a hostname_alias in CONFIG_FILE
if [ -n "$APPOPTICS_HOSTNAME" ]; then
    sed "s/# hostname_alias: myhostname/hostname_alias: $APPOPTICS_HOSTNAME/" $CONFIG_FILE > $TMP_FILE
    cp $TMP_FILE $CONFIG_FILE
fi

exec /opt/appoptics/sbin/snapteld --config $CONFIG_FILE
