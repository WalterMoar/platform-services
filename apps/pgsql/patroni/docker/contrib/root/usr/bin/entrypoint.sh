#!/bin/bash

if [[ $UID -ge 10000 ]]; then
    GID=$(id -g)
    sed -e "s/^postgres:x:[^:]*:[^:]*:/postgres:x:$UID:$GID:/" /etc/passwd > /tmp/passwd
    cat /tmp/passwd > /etc/passwd
    rm /tmp/passwd
fi

# FIX -> FATAL:  data directory "..." has group or world access
mkdir -p "$PATRONI_POSTGRESQL_DATA_DIR"
chmod 700 "$PATRONI_POSTGRESQL_DATA_DIR"

cat > /home/postgres/patroni.yml <<__EOF__
bootstrap:
  post_bootstrap: /usr/share/scripts/patroni/post_init.sh
  dcs:
    postgresql:
      use_pg_rewind: true
      parameters:
        checkpoint_completion_target: ${POSTGRESQL_CHECKPOINT_COMPLETION_TARGET:0.5}
        effective_cache_size: ${POSTGRESQL_EFFECTIVE_CACHE_SIZE:524288}
        effective_io_concurrency: ${POSTGRESQL_EFFECTIVE_IO_CONCURRENCY:1}
        idle_in_transaction_session_timeout: ${POSTGRESQL_IDLE_IN_TRANSACTION_SESSION_TIMEOUT:0}
        log_autovacuum_min_duration: ${POSTGRESQL_LOG_AUTOVACUUM_MIN_DURATION:-1}
        log_checkpoints: ${POSTGRESQL_LOG_CHECKPOINTS:off}
        log_lock_waits: ${POSTGRESQL_LOG_LOCK_WAITS:off}
        log_min_duration_statement: ${POSTGRESQL_LOG_MIN_DURATION_STATEMENT:-1}
        log_temp_files: ${POSTGRESQL_LOG_TEMP_FILES:-1}
        maintenance_work_mem: ${POSTGRESQL_MAINTENANCE_WORK_MEM:65536}
        max_connections: ${POSTGRESQL_MAX_CONNECTIONS:-100}
        max_locks_per_transaction: ${POSTGRESQL_MAX_LOCKS_PER_TRANSACTION:-64}
        max_parallel_workers: ${POSTGRESQL_MAX_PARALLEL_WORKERS:8}
        max_parallel_workers_per_gather: ${POSTGRESQL_MAX_PARALLEL_WORKERS_PER_GATHER:2}
        max_prepared_transactions: ${POSTGRESQL_MAX_PREPARED_TRANSACTIONS:-0}
        max_wal_size: ${POSTGRESQL_MAX_WAL_SIZE:1024}
        min_wal_size: ${POSTGRESQL_MIN_WAL_SIZE:80}
        random_page_cost: ${POSTGRESQL_RANDOM_PAGE_COST:4}
        shared_buffers: ${POSTGRESQL_SHARED_BUFFERS:16384}
        track_io_timing: ${POSTGRESQL_TRACK_IO_TIMING:off}
        work_mem: ${POSTGRESQL_WORK_MEM:4096}
  initdb:
  - auth-host: md5
  - auth-local: trust
  - encoding: UTF8
  - locale: en_US.UTF-8
  - data-checksums
  pg_hba:
  - host all all 0.0.0.0/0 md5
  - host replication ${PATRONI_REPLICATION_USERNAME} ${POD_IP}/16    md5
restapi:
  connect_address: '${POD_IP}:8008'
postgresql:
  connect_address: '${POD_IP}:5432'
  authentication:
    superuser:
      password: '${PATRONI_SUPERUSER_PASSWORD}'
    replication:
      password: '${PATRONI_REPLICATION_PASSWORD}'
__EOF__

unset PATRONI_SUPERUSER_PASSWORD PATRONI_REPLICATION_PASSWORD
export KUBERNETES_NAMESPACE=$PATRONI_KUBERNETES_NAMESPACE
export POD_NAME=$PATRONI_NAME

exec /usr/bin/python3 /usr/local/bin/patroni /home/postgres/patroni.yml
