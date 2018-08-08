#!/bin/bash

envsubst < ./connect-properties/connect-standalone.properties.template > ./connect-properties/connect-standalone.properties
envsubst < ./connect-properties/sink.properties.template > ./connect-properties/sink.properties
envsubst < ./newrelic/newrelic.yml.template > ./newrelic/newrelic.yml

CMD=${1:-"exit 0"}
if [[ "xxx$CMD" == "xxx" ]]
then
    exec /opt/kafka_2.11-0.11.0.0/bin/connect-standalone.sh ./connect-properties/connect-standalone.properties ./connect-properties/sink.properties
else
    /bin/bash -c "$*"
fi