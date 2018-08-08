#!/bin/bash

envsubst < ./connect-properties/connect-standalone.properties.template > ./connect-properties/connect-standalone.properties
envsubst < ./connect-properties/sink.properties.template > ./connect-properties/sink.properties
envsubst < ./newrelic/newrelic.yml.template > ./newrelic/newrelic.yml

if [[ "$#" -eq 0 ]]
then
    echo "Starting Connect..."
    exec /opt/kafka_2.11-${KAFKA_VERSION}/bin/connect-standalone.sh ./connect-properties/connect-standalone.properties ./connect-properties/sink.properties
else
    /bin/bash -c "$*"
fi