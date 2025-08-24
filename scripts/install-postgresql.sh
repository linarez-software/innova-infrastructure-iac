#!/bin/bash
# PostgreSQL v15 Installation Script for n2-highmem-4 (Production Database Server)
# Optimized for 4 vCPUs, 32 GB RAM dedicated PostgreSQL workload

set -e

# Configuration variables
PG_VERSION="${1:-15}"
DB_PASSWORD="${2:-changeme}"
ODOO_HOST="${3:-10.0.0.2}"
PG_DATA_DIR="/mnt/data/postgresql"
BACKUP_DIR="/backup/postgresql"

echo "Starting PostgreSQL v${PG_VERSION} installation optimized for n2-highmem-4..."

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install PostgreSQL repository
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list

apt-get update

# Install PostgreSQL and additional tools
apt-get install -y \
    postgresql-${PG_VERSION} \
    postgresql-client-${PG_VERSION} \
    postgresql-contrib-${PG_VERSION} \
    postgresql-server-dev-${PG_VERSION} \
    pgbouncer \
    postgresql-${PG_VERSION}-pg-stat-statements \
    postgresql-${PG_VERSION}-pglogical \
    htop \
    iotop \
    sysstat \
    rsync \
    gzip \
    python3-pip \
    curl

# Stop PostgreSQL for configuration
systemctl stop postgresql

# Setup additional data disk (if available)
if [ -b /dev/sdb ]; then
    echo "Setting up additional data disk for PostgreSQL..."
    parted -s /dev/sdb mklabel gpt
    parted -s /dev/sdb mkpart primary ext4 0% 100%
    mkfs.ext4 -F /dev/sdb1
    
    mkdir -p $PG_DATA_DIR
    mount /dev/sdb1 $PG_DATA_DIR
    echo "/dev/sdb1 $PG_DATA_DIR ext4 defaults,nofail,noatime 0 2" >> /etc/fstab
    
    # Set ownership
    chown -R postgres:postgres $PG_DATA_DIR
    
    # Initialize new data directory
    sudo -u postgres /usr/lib/postgresql/${PG_VERSION}/bin/initdb -D $PG_DATA_DIR/${PG_VERSION}/main
    
    # Update configuration to use new data directory
    systemctl stop postgresql
    sed -i "s|^data_directory.*|data_directory = '$PG_DATA_DIR/${PG_VERSION}/main'|" /etc/postgresql/${PG_VERSION}/main/postgresql.conf
fi

# Create backup directory
mkdir -p $BACKUP_DIR
chown postgres:postgres $BACKUP_DIR

# Configure PostgreSQL for high-memory workload (32GB RAM optimized)
cat > /etc/postgresql/${PG_VERSION}/main/conf.d/99-performance.conf << EOF
# PostgreSQL Performance Configuration for n2-highmem-4 (32GB RAM)
# Optimized for Odoo workload with 30 concurrent users

# Memory Configuration
shared_buffers = 8GB                    # 25% of RAM
effective_cache_size = 24GB             # 75% of RAM
work_mem = 256MB                        # For complex queries
maintenance_work_mem = 2GB              # For maintenance operations
autovacuum_work_mem = 1GB              # For autovacuum

# Connection Settings
max_connections = 100                   # Reasonable limit with connection pooling
shared_preload_libraries = 'pg_stat_statements'

# Checkpoint Configuration
checkpoint_completion_target = 0.9
checkpoint_timeout = 10min
max_wal_size = 4GB
min_wal_size = 1GB
wal_buffers = 16MB

# Query Planner
random_page_cost = 1.1                  # SSD storage assumption
effective_io_concurrency = 200          # For SSD
seq_page_cost = 1.0

# Background Writer
bgwriter_delay = 200ms
bgwriter_lru_maxpages = 100
bgwriter_lru_multiplier = 2.0

# WAL Configuration
wal_level = replica
archive_mode = on
archive_command = 'gzip -c %p > ${BACKUP_DIR}/wal/%f.gz'
max_wal_senders = 3
wal_keep_size = 1GB

# Autovacuum Configuration
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 1min
autovacuum_vacuum_threshold = 50
autovacuum_vacuum_scale_factor = 0.02
autovacuum_analyze_threshold = 50
autovacuum_analyze_scale_factor = 0.01

# Logging Configuration
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_file_mode = 0600
log_rotation_age = 1d
log_rotation_size = 1GB
log_min_duration_statement = 250ms      # Log slow queries
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0
log_line_prefix = '%m [%p] %q%u@%d '
log_statement = 'ddl'

# pg_stat_statements Configuration
pg_stat_statements.max = 10000
pg_stat_statements.track = all
pg_stat_statements.track_utility = off
pg_stat_statements.save = on

# Network Configuration
listen_addresses = '*'
port = 5432
max_prepared_transactions = 0

# Lock Management
deadlock_timeout = 1s
max_locks_per_transaction = 64
max_pred_locks_per_transaction = 64
EOF

# Configure host-based authentication
cat > /etc/postgresql/${PG_VERSION}/main/pg_hba.conf << EOF
# PostgreSQL Client Authentication Configuration
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             postgres                                peer
local   all             all                                     peer

# IPv4 local connections
host    all             all             127.0.0.1/32            scram-sha-256

# Allow connections from Odoo server
host    all             odoo            ${ODOO_HOST}/32         scram-sha-256
host    all             odoo            10.0.0.0/24             scram-sha-256

# Replication connections
host    replication     postgres        ${ODOO_HOST}/32         scram-sha-256

# IPv6 local connections
host    all             all             ::1/128                 scram-sha-256
EOF

# Create WAL archive directory
mkdir -p ${BACKUP_DIR}/wal
chown postgres:postgres ${BACKUP_DIR}/wal

# Start PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Wait for PostgreSQL to start
sleep 5

# Create database and user for Odoo
sudo -u postgres psql << EOF
-- Set password for postgres user
ALTER USER postgres PASSWORD '${DB_PASSWORD}';

-- Create Odoo user
CREATE USER odoo WITH PASSWORD '${DB_PASSWORD}';
ALTER USER odoo CREATEDB;

-- Create extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Set timezone
ALTER SYSTEM SET timezone = 'UTC';

-- Reload configuration
SELECT pg_reload_conf();
EOF

# Configure PgBouncer for connection pooling
cat > /etc/pgbouncer/pgbouncer.ini << EOF
[databases]
* = host=127.0.0.1 port=5432 auth_user=postgres

[pgbouncer]
listen_port = 6432
listen_addr = *
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
auth_query = SELECT usename, passwd FROM pg_shadow WHERE usename = \$1

admin_users = postgres
stats_users = postgres

pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
max_user_connections = 100

server_reset_query = DISCARD ALL
server_check_query = select 1
server_check_delay = 30

ignore_startup_parameters = extra_float_digits

log_connections = 1
log_disconnections = 1
log_pooler_errors = 1

pidfile = /var/run/postgresql/pgbouncer.pid
unix_socket_dir = /var/run/postgresql
EOF

# Create PgBouncer user list
echo "\"postgres\" \"$(echo -n "${DB_PASSWORD}postgres" | sha256sum | cut -d' ' -f1)\"" > /etc/pgbouncer/userlist.txt
echo "\"odoo\" \"$(echo -n "${DB_PASSWORD}odoo" | sha256sum | cut -d' ' -f1)\"" >> /etc/pgbouncer/userlist.txt

chown postgres:postgres /etc/pgbouncer/userlist.txt
chmod 600 /etc/pgbouncer/userlist.txt

# Start and enable PgBouncer
systemctl enable pgbouncer
systemctl start pgbouncer

# Create backup script
cat > ${BACKUP_DIR}/backup.sh << 'EOF'
#!/bin/bash
# PostgreSQL Backup Script

BACKUP_DIR="/backup/postgresql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Create backup directory structure
mkdir -p ${BACKUP_DIR}/dumps
mkdir -p ${BACKUP_DIR}/wal
mkdir -p ${BACKUP_DIR}/logs

# Function to log messages
log() {
    echo "$(date): $1" | tee -a ${BACKUP_DIR}/logs/backup.log
}

log "Starting PostgreSQL backup..."

# Get list of databases (excluding system databases)
DATABASES=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres', 'template0', 'template1');")

# Backup each database
for DB in $DATABASES; do
    if [ ! -z "$DB" ]; then
        log "Backing up database: $DB"
        sudo -u postgres pg_dump -Fc -b -v -f "${BACKUP_DIR}/dumps/${DB}_${TIMESTAMP}.backup" "$DB"
        
        if [ $? -eq 0 ]; then
            log "Successfully backed up database: $DB"
        else
            log "ERROR: Failed to backup database: $DB"
        fi
    fi
done

# Backup global objects (users, tablespaces, etc.)
log "Backing up global objects..."
sudo -u postgres pg_dumpall -g -f "${BACKUP_DIR}/dumps/globals_${TIMESTAMP}.sql"

# Compress old backups
find ${BACKUP_DIR}/dumps -name "*.backup" -mtime +1 -exec gzip {} \;
find ${BACKUP_DIR}/dumps -name "*.sql" -mtime +1 -exec gzip {} \;

# Remove old backups
log "Cleaning up old backups (older than ${RETENTION_DAYS} days)..."
find ${BACKUP_DIR}/dumps -name "*.gz" -mtime +${RETENTION_DAYS} -delete
find ${BACKUP_DIR}/wal -name "*.gz" -mtime +${RETENTION_DAYS} -delete

# Clean up old WAL files
sudo -u postgres psql -c "SELECT pg_switch_wal();" > /dev/null

log "PostgreSQL backup completed."
EOF

chmod +x ${BACKUP_DIR}/backup.sh

# Add backup script to crontab (run daily at 2 AM)
echo "0 2 * * * root ${BACKUP_DIR}/backup.sh" >> /etc/crontab

# System optimizations for database workload
cat >> /etc/sysctl.conf << EOF

# PostgreSQL optimizations for n2-highmem-4
vm.swappiness = 1
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 250
kernel.shmmax = 17179869184
kernel.shmall = 4194304
kernel.shmmni = 4096
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

sysctl -p

# Configure logrotate for PostgreSQL logs
cat > /etc/logrotate.d/postgresql << EOF
/var/lib/postgresql/${PG_VERSION}/main/log/*.log {
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

${BACKUP_DIR}/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 postgres postgres
}
EOF

# Create monitoring script
cat > /usr/local/bin/pg-monitor.sh << 'EOF'
#!/bin/bash
# PostgreSQL Monitoring Script

echo "PostgreSQL Status:"
systemctl status postgresql --no-pager -l

echo -e "\nConnection Status:"
sudo -u postgres psql -c "SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';"

echo -e "\nDatabase Sizes:"
sudo -u postgres psql -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) as size FROM pg_database WHERE datistemplate = false ORDER BY pg_database_size(datname) DESC;"

echo -e "\nTop 10 Largest Tables:"
sudo -u postgres psql -c "SELECT schemaname,tablename,attname,n_distinct,correlation FROM pg_stats WHERE schemaname NOT IN ('information_schema', 'pg_catalog') ORDER BY n_distinct DESC LIMIT 10;"

echo -e "\nSlowest Queries (from pg_stat_statements):"
sudo -u postgres psql -c "SELECT query, calls, total_time, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"

echo -e "\nPgBouncer Status:"
systemctl status pgbouncer --no-pager -l
EOF

chmod +x /usr/local/bin/pg-monitor.sh

echo "PostgreSQL v${PG_VERSION} installation completed successfully!"
echo ""
echo "Configuration Summary:"
echo "  - PostgreSQL version: ${PG_VERSION}"
echo "  - Data directory: ${PG_DATA_DIR}/${PG_VERSION}/main"
echo "  - Backup directory: ${BACKUP_DIR}"
echo "  - Connection pooler: PgBouncer (port 6432)"
echo "  - Max connections: 100"
echo "  - Shared buffers: 8GB"
echo "  - Effective cache size: 24GB"
echo ""
echo "Performance Features:"
echo "  - Optimized for 32GB RAM workload"
echo "  - Connection pooling with PgBouncer"
echo "  - Automated backups (daily at 2 AM)"
echo "  - WAL archiving enabled"
echo "  - pg_stat_statements enabled"
echo "  - System kernel optimizations applied"
echo ""
echo "Useful Commands:"
echo "  - Monitor status: /usr/local/bin/pg-monitor.sh"
echo "  - Manual backup: ${BACKUP_DIR}/backup.sh"
echo "  - Connect to PostgreSQL: sudo -u postgres psql"
echo "  - Connect via PgBouncer: psql -h localhost -p 6432 -U postgres"
echo ""
echo "Next Steps:"
echo "1. Configure firewall to allow connections from Odoo server (${ODOO_HOST})"
echo "2. Test connectivity from Odoo server"
echo "3. Monitor performance and adjust configuration if needed"