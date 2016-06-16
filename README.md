#kafka-marathon

Dockerfile to run Apache Kafka on Marathon

##Usage

- network: HOST
- PORT0: kafka port
- PORT1: jmx port
- HOSTNAME_COMMAND: `hostname`
- KAFKA_ZOOKEEPER_CONNECT: zk-hostname:port/kafka
- KAFKA_LOG_DIRS: `data`
- persistent volume: `data`
