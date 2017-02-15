#!/bin/sh

set -e

# Map stdout to fd 6, then redirect stdout to stderr
exec 6>&1
exec >&2

CASSANDRA_ACI=https://github.com/dit4c/container-cassandra-etcd/releases/download/0.1.0/cassandra-etcd.linux.amd64.aci
TMP_DIR=$(mktemp -d -t cassandra-backup-XXXXXXXX)
TMP_FIFO=$TMP_DIR/backup.tar
mkfifo $TMP_FIFO
chmod 0755 $TMP_DIR
chmod 0777 $TMP_FIFO

# Output anything sent to the FIFO to stdout
cat $TMP_FIFO >&6 &
OUTPUT_PID=$!

sudo `which rkt` run --net=host $CASSANDRA_ACI \
  --volume volume-var-lib-cassandra,kind=host,source=/var/lib/cassandra \
  --mount volume=backup,target=/var/backup \
  --volume backup,kind=host,source=$TMP_DIR \
  --exec /bin/sh -- -c "
set -e

mkdir -p /tmp/schema
cqlsh $COREOS_PRIVATE_IPV4 -e 'DESC SCHEMA' > /tmp/schema/desc_schema.cql
nodetool -h $COREOS_PRIVATE_IPV4 clearsnapshot
nodetool -h $COREOS_PRIVATE_IPV4 snapshot

ls -la /var/backup

(cd /var/lib/cassandra && find data -type f -path '*/snapshots/*') | \
  tar cv -C /tmp schema -C /var/lib/cassandra -T - > /var/backup/backup.tar

nodetool -h $COREOS_PRIVATE_IPV4 clearsnapshot
"

wait $OUTPUT_PID
rm -rf $TMP_DIR
