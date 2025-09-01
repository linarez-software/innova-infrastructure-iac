#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y wget gnupg2 lsb-release

wget -q -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
apt-get update
apt-get install -y \
    postgresql-${postgresql_version} \
    postgresql-client-${postgresql_version} \
    postgresql-contrib-${postgresql_version} \
    pgbouncer \
    pg-stat-kcache-${postgresql_version} \
    postgresql-${postgresql_version}-pg-stat-statements

systemctl stop postgresql

if [ -b /dev/sdb ]; then
    mkfs.ext4 /dev/sdb
    mkdir -p /mnt/data
    mount /dev/sdb /mnt/data
    echo "/dev/sdb /mnt/data ext4 defaults,nofail 0 0" >> /etc/fstab
    
    mkdir -p /mnt/data/postgresql
    chown -R postgres:postgres /mnt/data/postgresql
    
    echo "data_directory = '/mnt/data/postgresql/${postgresql_version}/main'" >> /etc/postgresql/${postgresql_version}/main/postgresql.conf
    
    sudo -u postgres /usr/lib/postgresql/${postgresql_version}/bin/initdb -D /mnt/data/postgresql/${postgresql_version}/main
fi

cat >> /etc/postgresql/${postgresql_version}/main/postgresql.conf <<EOL

shared_buffers = 8GB
effective_cache_size = 24GB
maintenance_work_mem = 2GB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 256MB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 4
max_parallel_workers_per_gather = 2
max_parallel_workers = 4
max_connections = 100

logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 1GB
log_min_duration_statement = 200
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0
log_error_verbosity = default

shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.max = 10000
pg_stat_statements.track = all

listen_addresses = '*'
EOL

cat > /etc/postgresql/${postgresql_version}/main/pg_hba.conf <<EOL
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
host    all             all             10.0.0.0/24             md5
host    all             appuser         10.0.0.0/24             md5
EOL

systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql <<EOF
ALTER USER postgres PASSWORD '${db_password}';
CREATE USER appuser WITH PASSWORD '${db_password}';
ALTER USER appuser CREATEDB;
CREATE DATABASE appdb OWNER appuser;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
EOF

cat > /etc/pgbouncer/pgbouncer.ini <<EOL
[databases]
* = host=127.0.0.1 port=5432

[pgbouncer]
listen_port = 6432
listen_addr = *
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
max_db_connections = 100
max_user_connections = 100
server_lifetime = 3600
server_idle_timeout = 600
server_connect_timeout = 15
server_login_retry = 15
query_wait_timeout = 120
client_idle_timeout = 0
client_login_timeout = 60
admin_users = postgres
stats_users = postgres
ignore_startup_parameters = extra_float_digits
logfile = /var/log/postgresql/pgbouncer.log
pidfile = /var/run/postgresql/pgbouncer.pid
EOL

echo "\"appuser\" \"md5$(echo -n '${db_password}appuser' | md5sum | cut -d' ' -f1)\"" > /etc/pgbouncer/userlist.txt
echo "\"postgres\" \"md5$(echo -n '${db_password}postgres' | md5sum | cut -d' ' -f1)\"" >> /etc/pgbouncer/userlist.txt

chown postgres:postgres /etc/pgbouncer/userlist.txt
chmod 600 /etc/pgbouncer/userlist.txt

systemctl restart pgbouncer
systemctl enable pgbouncer

mkdir -p /backup/scripts
cat > /backup/scripts/backup.sh <<'EOL'
#!/bin/bash
BACKUP_DIR="/backup/postgresql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="appdb"

mkdir -p $BACKUP_DIR

for DB in $(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';"); do
    sudo -u postgres pg_dump -Fc -b -v -f "$BACKUP_DIR/$${DB}_$${TIMESTAMP}.backup" $DB
done

find $BACKUP_DIR -name "*.backup" -mtime +30 -delete

gsutil -m rsync -r $BACKUP_DIR gs://${project_id}-backups/postgresql/
EOL

chmod +x /backup/scripts/backup.sh

echo "0 2 * * * root /backup/scripts/backup.sh >> /var/log/backup.log 2>&1" >> /etc/crontab

echo "vm.swappiness = 10" >> /etc/sysctl.conf
echo "vm.dirty_ratio = 15" >> /etc/sysctl.conf
echo "vm.dirty_background_ratio = 5" >> /etc/sysctl.conf
sysctl -p

cat > /etc/logrotate.d/postgresql <<EOL
/var/log/postgresql/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 postgres postgres
    sharedscripts
    postrotate
        systemctl reload postgresql > /dev/null 2>&1 || true
    endscript
}
EOL

echo "PostgreSQL ${postgresql_version} installation and configuration completed successfully!"