#!/usr/bin/env bash

if [[ -z "$KAFKA_LISTENERS" ]]; then
  KAFKA_PORT=${KAFKA_PORT:-${PORT0:-9092}}
  KAFKA_ADVERTISED_PORT=${KAFKA_ADVERTISED_PORT:-${PORT0:-$KAFKA_PORT}}
  if [[ -z "$KAFKA_ADVERTISED_HOST_NAME" && -n "$HOSTNAME_COMMAND" ]]; then
    KAFKA_ADVERTISED_HOST_NAME=$(eval $HOSTNAME_COMMAND)
  fi
  export KAFKA_LISTENERS="PLAINTEXT://0.0.0.0:$KAFKA_PORT"
  export KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://$KAFKA_ADVERTISED_HOST_NAME:$KAFKA_ADVERTISED_PORT"
  unset KAFKA_PORT
  unset KAFKA_ADVERTISED_PORT
  unset KAFKA_ADVERTISED_HOST_NAME
fi

if [[ -z "$KAFKA_BROKER_ID" ]]; then
  # By default auto allocate broker ID
  export KAFKA_BROKER_ID=-1
fi
if [[ -z "$KAFKA_LOG_DIRS" ]]; then
  export KAFKA_LOG_DIRS="/data"
fi
if [[ -z "$KAFKA_ZOOKEEPER_CONNECT" ]]; then
  export KAFKA_ZOOKEEPER_CONNECT=$(env | grep ZK.*PORT_2181_TCP= | sed -e 's|.*tcp://||' | paste -sd ,)
fi

if [[ -n "$KAFKA_HEAP_OPTS" ]]; then
  sed -r -i "s/(export KAFKA_HEAP_OPTS)=\"(.*)\"/\1=\"$KAFKA_HEAP_OPTS\"/g" $KAFKA_HOME/bin/kafka-server-start.sh
  unset KAFKA_HEAP_OPTS
fi

for VAR in `env`; do
  if [[ $VAR =~ ^KAFKA_ && ! $VAR =~ ^KAFKA_HOME ]]; then
    kafka_name=`echo "$VAR" | sed -r "s/KAFKA_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | tr _ .`
    env_var=`echo "$VAR" | sed -r "s/(.*)=.*/\1/g"`
    if egrep -q "(^|^#)$kafka_name=" $KAFKA_HOME/config/server.properties; then
      # NOTE: no config values may contain an '@' char
      sed -r -i "s@(^|^#)($kafka_name)=(.*)@\2=${!env_var}@g" $KAFKA_HOME/config/server.properties
    else
      echo "$kafka_name=${!env_var}" >> $KAFKA_HOME/config/server.properties
    fi
  fi
done

if [[ -z "$JMX_PORT" && -n "$PORT1" ]]; then
  export JMX_PORT=$PORT1
fi

if [ -z $KAFKA_JMX_OPTS ]; then
  KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote=true"
  KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.authenticate=false"
  KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.ssl=false"
  KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT"
  KAFKA_JMX_OPTS="$KAFKA_JMX_OPTS -Djava.rmi.server.hostname=${JAVA_RMI_SERVER_HOSTNAME:-$KAFKA_ADVERTISED_HOST_NAME} "
  export KAFKA_JMX_OPTS
fi

KAFKA_PID=0

# see https://medium.com/@gchudnov/trapping-signals-in-docker-containers-7a57fdda7d86#.bh35ir4u5
term_handler() {
  echo 'Stopping Kafka....'
  if [ $KAFKA_PID -ne 0 ]; then
    kill -s TERM "$KAFKA_PID"
    wait "$KAFKA_PID"
  fi
  echo 'Kafka stopped.'
  exit
}


# Capture kill requests to stop properly
trap "term_handler" SIGHUP SIGINT SIGTERM
$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties &
KAFKA_PID=$!

wait
