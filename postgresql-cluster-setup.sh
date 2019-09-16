#!/bin/bash

POSTGRESQL_VERSION=9.6
PGBOUNCER_VERSION=1.11.0-1.pgdg16.04+1
CONSUL_VERSION=1.4.5
PATRONI_VERSION=1.6.0
PSYCOPG2_VERSION=2.8.3
PYCONSUL_VERSION=1.1.0

PG_PATH="/etc/postgresql/${POSTGRESQL_VERSION}/main"

function setup_packages() {
    apt-get update
    apt-get -y install wget unzip curl libpq-dev ca-certificates ntp tree
}

function setup_python() {
    apt-get -y install python python-pip
}

function setup_patroni() {
    # Install
    pip install psycopg2-binary==${PSYCOPG2_VERSION}
    pip install python-consul==${PYCONSUL_VERSION}
    pip install patroni[consul]==${PATRONI_VERSION}
    mkdir -p /etc/patroni
    mkdir -p /var/lib/postgresql/patroni
    chmod 700 /var/lib/postgresql/patroni
    mkdir -p /var/log/patroni
    chmod 777 /var/log/patroni

    # Configure
    if [ "$(hostname)" == "pg01" ]; then
        cp -p /vagrant/patroni01.yml /etc/patroni/patroni.yml
    elif [ "$(hostname)" == "pg02" ]; then # consul server and client
        cp -p /vagrant/patroni02.yml /etc/patroni/patroni.yml
    fi
    cp -p /vagrant/patroni.service /etc/systemd/system/
    systemctl daemon-reload
}

function setup_consul() {
    # Install
    curl -s -O https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
    unzip consul_${CONSUL_VERSION}_linux_amd64.zip
    mv consul /usr/local/bin/
    rm -f consul_${CONSUL_VERSION}_linux_amd64.zip
    mkdir -p /etc/consul.d/{server,client}

    if [ "$(hostname)" == "pg01" ]; then
        cp -p /vagrant/consul.d/client/pg01.json /etc/consul.d/client/pg01.json
    fi
    if [ "$(hostname)" == "pg02" ]; then
        cp -p /vagrant/consul.d/client/pg02.json /etc/consul.d/client/pg02.json
    fi
    if [ "$(hostname)" == "pg03" ]; then
        cp -rp /vagrant/consul.d/server/ /etc/consul.d
    fi
    mkdir -p /var/consul/ui
    useradd -M -d /var/consul -s /bin/bash consul

    # Configure consul service
    mkdir -p /var/consul/{server,client}
    if [ "$(hostname)" == "pg01" ]; then # consul client
        cp -p /vagrant/consul-client.service /etc/systemd/system/
    fi
    if [ "$(hostname)" == "pg02" ]; then # consul client
        cp -p /vagrant/consul-client.service /etc/systemd/system/
    fi
    if [ "$(hostname)" == "pg03" ]; then # consul server
        cp -p /vagrant/consul-server.service /etc/systemd/system/
    fi
    systemctl daemon-reload

    chown -R consul:consul /var/consul/

    if [ "$(hostname)" == "pg01" ]; then
        systemctl start consul-client
        systemctl enable consul-client
    fi
    if [ "$(hostname)" == "pg02" ]; then
        systemctl start consul-client
        systemctl enable consul-client
    fi
    if [ "$(hostname)" == "pg03" ]; then
        systemctl start consul-server
        systemctl enable consul-server
    fi
}

function setup_haproxy() {
    # Install
    apt-get install haproxy -y

    # Configure
    cp -p /vagrant/haproxy.cfg /etc/haproxy/haproxy.cfg

    systemctl restart haproxy
    systemctl enable haproxy
    # Check syntax if fails: /usr/sbin/haproxy -c -V -f /etc/haproxy/haproxy.cfg
}

function setup_pgbouncer() {
    # to be able to run python scripts
    pip install psycopg2-binary==${PSYCOPG2_VERSION}

    # Install the version that comes with the official apt postgresql repository
    apt-get -y install pgbouncer=${PGBOUNCER_VERSION} postgresql-client-${POSTGRESQL_VERSION}

    cat > /etc/pgbouncer/pgbouncer.ini <<EOF
[databases]
postgres = host=172.28.33.13 port=5000 pool_size=6
template1 = host=172.28.33.13 port=5000 pool_size=6
test = host=172.28.33.13 port=5000 pool_size=6

[pgbouncer]
logfile = /var/log/postgresql/pgbouncer.log
pidfile = /var/run/postgresql/pgbouncer.pid
listen_addr = *
listen_port = 6432
unix_socket_dir = /var/run/postgresql
auth_type = trust
auth_file = /etc/pgbouncer/userlist.txt
admin_users = postgres
stats_users =
pool_mode = transaction
server_reset_query =
server_check_query = select 1
server_check_delay = 10
max_client_conn = 1000
default_pool_size = 12
reserve_pool_size = 5
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
EOF

    cat > /etc/pgbouncer/userlist.txt <<EOF
"postgres" "secretpassword"
EOF

    cat > /etc/default/pgbouncer <<EOF
START=1
EOF
    systemctl restart pgbouncer
    systemctl enable pgbouncer
}

function setup_postgresql_repo() {
    # Setup postgresql repo
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

    # Setup postgresql repo key
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

    apt-get update
    #apt-get -y upgrade
}


function setup_postgresql() {
    # Install postgresql
    apt-get -y install postgresql-${POSTGRESQL_VERSION}

    systemctl stop postgresql
    systemctl disable postgresql

    chown -R postgres:postgres /var/lib/postgresql/patroni
    chown -R postgres:postgres /etc/patroni

#    cat > ${PG_PATH}/pg_hba.conf <<EOF
#local   all             postgres                                peer
#
## TYPE  DATABASE        USER            ADDRESS                 METHOD
#
## "local" is for Unix domain socket connections only
#local   all             all                                     peer
## IPv4 local connections:
#host    all             all             127.0.0.1/32            md5
## IPv6 local connections:
#host    all             all             ::1/128                 md5
## Allow replication connections from localhost, by a user with the
## replication privilege.
##local   replication     postgres                                peer
##host    replication     postgres        127.0.0.1/32            md5
#host    replication     postgres        ::1/128                 md5
#hostssl    replication     postgres 172.28.33.11/32                 trust
#hostssl    replication     postgres 172.28.33.12/32                 trust
## for user connections
#host       all     postgres 172.28.33.1/32                 trust
#hostssl    all     postgres 172.28.33.1/32                 trust
## for pgbouncer
#host       all     postgres 172.28.33.10/32                 trust
#hostssl    all     postgres 172.28.33.10/32                 trust
#host       all     postgres 172.28.33.11/32                 trust
#hostssl    all     postgres 172.28.33.11/32                 trust
#host       all     postgres 172.28.33.12/32                 trust
#hostssl    all     postgres 172.28.33.12/32                 trust
#EOF
#
#    cat > ${PG_PATH}/postgresql.conf <<EOF
#archive_command = 'exit 0'
#archive_mode = 'on'
#autovacuum = 'on'
#checkpoint_completion_target = 0.6
##checkpoint_segments = 10
#checkpoint_warning = 300
#data_directory = '/var/lib/postgresql/${POSTGRESQL_VERSION}/main'
#datestyle = 'iso, mdy'
#default_text_search_config = 'pg_catalog.english'
#effective_cache_size = '128MB'
#external_pid_file = '/var/run/postgresql/${POSTGRESQL_VERSION}-main.pid'
#hba_file = '${PG_PATH}/pg_hba.conf'
#hot_standby = 'on'
#ident_file = '${PG_PATH}/pg_ident.conf'
#include_if_exists = 'repmgr_lib.conf'
#lc_messages = 'C'
#listen_addresses = '*'
#log_autovacuum_min_duration = 0
#log_checkpoints = 'on'
#logging_collector = 'on'
#log_min_messages = DEBUG3
#log_filename = 'postgresql.log'
#log_connections = 'on'
#log_directory = '/var/log/postgresql'
#log_disconnections = 'on'
#log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a '
#log_lock_waits = 'on'
#log_min_duration_statement = 0
#log_temp_files = 0
#maintenance_work_mem = '128MB'
#max_connections = 100
#max_wal_senders = 5
#port = 5432
#shared_buffers = '128MB'
#shared_preload_libraries = 'pg_stat_statements'
#ssl = on
#ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
#ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'
#unix_socket_directories = '/var/run/postgresql'
#wal_buffers = '8MB'
#wal_keep_segments = '200'
#wal_level = 'replica'
#work_mem = '128MB'
#EOF

    # Make sure patroni can find all the postgresql binaries
    ln -f -s /usr/lib/postgresql/${POSTGRESQL_VERSION}/bin/* /usr/bin/

    # start patroni after all
    systemctl start patroni
    systemctl enable patroni
}

# Set the timezone (you might change it)
timedatectl set-timezone Europe/Madrid

setup_packages

if [ ! -f /usr/bin/pip ]; then
    setup_python
fi

if [ "$(hostname)" != "pg03" ]; then
    if [ ! -f /usr/local/bin/patroni ]; then
        setup_patroni
    fi
fi

if [ ! -f /usr/local/bin/consul ]; then
    setup_consul
fi

# Install HAProxy only in the pg03 host when bootstrapping
if [ "$(hostname)" == "pg03" ]; then
    if [ ! -f /etc/haproxy/haproxy.cfg ]; then
        setup_haproxy
    fi
fi

if [ ! -f /etc/apt/sources.list.d/pgdg.list ]; then
    setup_postgresql_repo
fi

if [ "$(hostname)" != "pg03" ]; then
    if [ ! -f ${PG_PATH}/postgresql.conf ]; then
        setup_postgresql
    fi
fi

if [ "$(hostname)" == "pg03" ]; then
    if [ ! -f /etc/pgbouncer/pgbouncer.ini ]; then
        setup_pgbouncer
    fi
fi
