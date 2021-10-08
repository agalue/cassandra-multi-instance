#cloud-config

# This is a Terraform template_file. It cannot be used directly as a cloud-init script.
# https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file

package_upgrade: false
timezone: America/New_York

write_files:
- owner: root:root
  path: /etc/sysctl.d/99-cassandra.conf
  content: |
    # https://docs.datastax.com/en/dse/6.8/dse-admin/datastax_enterprise/config/configRecommendedSettings.html#Persistupdatedsettings
    net.ipv4.tcp_keepalive_time=60
    net.ipv4.tcp_keepalive_probes=3
    net.ipv4.tcp_keepalive_intvl=10
    net.core.rmem_max=16777216
    net.core.wmem_max=16777216
    net.core.rmem_default=16777216
    net.core.wmem_default=16777216
    net.core.optmem_max=40960
    net.ipv4.tcp_rmem=4096 87380 16777216
    net.ipv4.tcp_wmem=4096 65536 16777216
    net.ipv4.tcp_window_scaling=1
    net.core.netdev_max_backlog=2500
    net.core.somaxconn=65000
    vm.swappiness=1
    vm.zone_reclaim_mode=0
    vm.max_map_count=1048575

- owner: root:root
  path: /etc/systemd/system/disable-thp.service
  content: |
    # For more information: https://tobert.github.io/tldr/cassandra-java-huge-pages.html
    [Unit]
    Description=Disable Transparent Huge Pages (THP)
    [Service]
    Type=simple
    ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag"
    [Install]
    WantedBy=multi-user.target

- owner: root:root
  path: /etc/systemd/system/cassandra3@.service
  content: |
    [Unit]
    Description=Cassandra
    Documentation=http://cassandra.apache.org
    Wants=network-online.target
    After=network-online.target
    [Service]
    Type=forking
    User=cassandra
    Group=cassandra
    Environment="CASSANDRA_HOME=/usr/share/cassandra"
    Environment="CASSANDRA_CONF=/etc/cassandra/%i"
    Environment="CASSANDRA_LOG_DIR=/var/log/cassandra/%i"
    Environment="PID_FILE=/var/run/cassandra/%i.pid"
    ExecStart=/usr/sbin/cassandra -p $PID_FILE
    StandardOutput=syslog
    StandardError=syslog
    SyslogIdentifier=cassandra-%i
    LimitNOFILE=100000
    LimitMEMLOCK=infinity
    LimitNPROC=32768
    LimitAS=infinity
    [Install]
    WantedBy=multi-user.target

- owner: root:root
  path: /etc/cassandra/fix-schema.cql
  content: |
    ALTER KEYSPACE system_auth WITH REPLICATION = {
      'class' : 'NetworkTopologyStrategy',
      '${dc_name}' : ${replication_factor}
    };
    ALTER KEYSPACE system_distributed WITH REPLICATION = {
      'class' : 'NetworkTopologyStrategy',
      '${dc_name}' : ${replication_factor}
    };
    ALTER KEYSPACE system_traces WITH REPLICATION = {
      'class' : 'NetworkTopologyStrategy',
      '${dc_name}' : ${replication_factor}
    };

- owner: root:root
  path: /etc/cassandra/newts_keyspace.cql
  content: |
    CREATE KEYSPACE IF NOT EXISTS ${newts_keyspace} WITH replication = {
      'class' : 'SimpleStrategy',
      'replication_factor' : ${replication_factor}
    };

- owner: root:root
  path: /etc/cassandra/newts_keyspace_nts.cql
  content: |
    CREATE KEYSPACE IF NOT EXISTS ${newts_keyspace} WITH replication = {
      'class' : 'NetworkTopologyStrategy',
      '${dc_name}' : ${replication_factor}
    };

- owner: root:root
  path: /etc/cassandra/newts_tables.cql
  content: |
    CREATE TABLE IF NOT EXISTS ${newts_keyspace}.samples (
      context text,
      partition int,
      resource text,
      collected_at timestamp,
      metric_name text,
      value blob,
      attributes map<text, text>,
      PRIMARY KEY((context, partition, resource), collected_at, metric_name)
    ) WITH compaction = {
      'compaction_window_size': '${compaction_window_size}',
      'compaction_window_unit': '${compaction_window_unit}',
      'expired_sstable_check_frequency_seconds': '${expired_sstable_check}',
      'class':  'org.apache.cassandra.db.compaction.TimeWindowCompactionStrategy'
    } AND gc_grace_seconds = ${gc_grace_seconds};
    CREATE TABLE IF NOT EXISTS ${newts_keyspace}.terms (
      context text,
      field text,
      value text,
      resource text,
      PRIMARY KEY((context, field, value), resource)
    );
    CREATE TABLE IF NOT EXISTS ${newts_keyspace}.resource_attributes (
      context text,
      resource text,
      attribute text,
      value text,
      PRIMARY KEY((context, resource), attribute)
    );
    CREATE TABLE IF NOT EXISTS ${newts_keyspace}.resource_metrics (
      context text,
      resource text,
      metric_name text,
      PRIMARY KEY((context, resource), metric_name)
    );

- owner: root:root
  permissions: '0750'
  path: /etc/cassandra/bootstrap.sh
  content: |
    #!/bin/bash
    set -x
    # WARNING: This script is designed to be executed once.
    # For SimpleSnitch starts one instance at a time in physical order.
    # For GossipingPropertyFileSnitch starts one instance at a time per server/rack.
    function wait_for_seed {
      until echo -n >/dev/tcp/${seed_host}/9042 2>/dev/null; do
        printf '.'
        sleep 10
      done
      echo "done"
    }
    function get_running_instances {
      echo $(nodetool -u cassandra -pw cassandra -h ${seed_host} status | grep "^UN" | wc -l)
    }
    if [ ! -f "/etc/cassandra/.configured" ]; then
      echo "Cassandra is not configured."
      exit
    fi
    if [ "$(id -u -n)" != "root" ]; then
      echo "Error: you must run this script as root" >&2
      exit 4  # According to LSB: 4 - user had insufficient privileges
    fi
    echo "### Bootstrapping Cassandra..."
    snitch="${endpoint_snitch}"
    instances=${number_of_instances}
    j=$(hostname | awk '{ print substr($0,length,1) }')
    systemctl daemon-reload
    systemctl restart snmpd
    systemctl restart rsyslog
    systemctl mask cassandra
    required_instances=0
    if [[ "$snitch" != "SimpleSnitch" ]]; then
      required_instances=$(($j - 1))
    fi
    for i in $(seq 1 $instances); do
      echo "Bootstrapping instance $i from server $j..."
      if [[ "$j" == "1" ]] && [[ "$i" == "1" ]]; then
        systemctl enable --now cassandra3@node$i
        wait_for_seed
        echo "Configuring keyspaces..."
        if [[ "$snitch" == "SimpleSnitch" ]]; then
          cqlsh -f /etc/cassandra/newts_keyspace.cql $(hostname)
        else
          cqlsh -f /etc/cassandra/fix-schema.cql $(hostname)
          cqlsh -f /etc/cassandra/newts_keyspace_nts.cql $(hostname)
        fi
        cqlsh -f /etc/cassandra/newts_tables.cql $(hostname)
      else
        wait_for_seed
        if [[ "$snitch" == "SimpleSnitch" ]]; then
          required_instances=$(($instances*($j-1) + ($i-1)))
        fi
        running_instances=$(get_running_instances)
        echo "Starting instance $i from server $j..."
        echo "Waiting to have $required_instances running..."
        until [[ $required_instances == $running_instances ]]; do
          printf '.'
          sleep 10;
          running_instances=$(get_running_instances)
        done
        echo "done"
        echo "Starting cassandra..."
        systemctl enable --now cassandra3@node$i
      fi
      if [[ "$snitch" != "SimpleSnitch" ]]; then
        required_instances=$(($required_instances + $instances))
      fi
    done

- owner: root:root
  permissions: '0750'
  path: /etc/cassandra/install.sh
  content: |
    #!/bin/bash
    set -x
    version="${version}"
    if [ "$(id -u -n)" != "root" ]; then
      echo "Error: you must run this script as root" >&2
      exit 4  # According to LSB: 4 - user had insufficient privileges
    fi
    echo "### Installing/Upgrading Cassandra..."
    repo_base="https://archive.apache.org/dist/cassandra"
    repo_ver="40x"
    if [[ "$version" == *"3.11."* ]]; then
      repo_ver="311x"
    fi
    if [[ "$version" == "latest" ]]; then
      cat <<EOF > /etc/yum.repos.d/cassandra.repo
    [cassandra]
    name=Apache Cassandra
    baseurl=$repo_base/redhat/$repo_ver
    gpgcheck=1
    repo_gpgcheck=1
    gpgkey=$repo_base/KEYS
    EOF
      yum install -y cassandra cassandra-tools
    else
      base="$repo_base/redhat/$repo_ver"
      suffix="$version-1.noarch.rpm"
      yum install -y $base/cassandra-$suffix $base/cassandra-tools-$suffix
    fi
    if [[ "$version" == *"3.11"* ]]; then
      yum install -y python2
      echo 3 | alternatives --config python; echo
    else
      yum install -y java-11-openjdk
      echo 2 | alternatives --config java; echo
      echo 2 | alternatives --config python; echo
    fi

- owner: root:root
  permissions: '0750'
  path: /etc/cassandra/configure_disks.sh
  content: |
    #!/bin/bash
    set -x
    if [[ "$(id -u -n)" != "root" ]]; then
      echo "Error: you must run this script as root" >&2
      exit 4  # According to LSB: 4 - user had insufficient privileges
    fi
    disks=${number_of_instances}
    directories=("commitlog" "data" "hints" "saved_caches")
    data_location=/var/lib/cassandra
    log_location=/var/log/cassandra
    echo "### Configuring Cassandra Data Disks..."
    if [ ! -f "/etc/fstab.bak" ]; then
      cp /etc/fstab /etc/fstab.bak
    fi
    echo "Waiting for $disks disks to be available"
    while [ $(ls -l /dev/disk/azure/scsi1 | grep lun | wc -l) -lt $disks ]; do
        printf '.'
      sleep 10
    done
    for i in $(seq 1 $disks); do
      disk=$(readlink -f /dev/disk/azure/scsi1/lun$(expr $i - 1))
      dev=$${disk}1
      if [ -e $dev ]; then
        # This script is designed to be executed once per disk device
        echo "Device $dev already configured, skipping."
        continue
      fi
      echo "Waiting for $disk to be ready"
      while [ ! -e $disk ]; do
        printf '.'
        sleep 10
      done
      echo "Configuring $disk"
      echo ';' | sfdisk $disk
      mkfs -t xfs -f $dev
      mount_point=/data/node$i
      mkdir -p $mount_point
      mkfs.xfs -f $dev $mount_point
      echo "$dev $mount_point xfs defaults,noatime 0 0" >> /etc/fstab
      mount $mount_point
      echo "Configuring data directory for $dev"
      location=$data_location/node$i
      ln -s /data/node$i $location
      for dir in "$${directories[@]}"; do
        mkdir -p $location/$dir
      done
      mkdir -p $log_location/node$i
      echo "disk $location" >> /etc/snmp/snmpd.conf
    done
    for dir in "$${directories[@]}"; do
      rmdir $data_location/$dir
    done
    chown -R cassandra:cassandra /data
    chown -R cassandra:cassandra $log_location

- owner: root:root
  permissions: '0750'
  path: /etc/cassandra/configure_rsyslog.sh
  content: |
    #!/bin/bash
    set -x
    if [[ "$(id -u -n)" != "root" ]]; then
      echo "Error: you must run this script as root" >&2
      exit 4  # According to LSB: 4 - user had insufficient privileges
    fi
    instances=${number_of_instances}
    echo "### Configuring rsyslog..."
    rsyslog_file=/etc/rsyslog.d/cassandra.conf
    rm -f $rsyslog_file
    for i in $(seq 1 $instances); do
      id=cassandra-node$i
      log=/var/log/cassandra/node$i/cassandra.log
      if ! grep -Fxq "$id" $rsyslog_file; then
        echo "if \$programname == '$id' then $log" >> $rsyslog_file
      fi
    done

- owner: root:root
  permissions: '0750'
  path: /etc/cassandra/configure_cassandra.sh
  content: |
    #!/bin/bash
    set -x
    version=$(rpm -q --queryformat '%%{VERSION}' cassandra)
    cluster_name="${cluster_name}"
    snitch="${endpoint_snitch}"
    dynamic_snitch="${dynamic_snitch}"
    num_tokens="${num_tokens}"
    seed_host="${seed_host}"
    dc_name="${dc_name}"
    instances=${number_of_instances}
    conf_src=/etc/cassandra/conf
    if [[ "$(id -u -n)" != "root" ]]; then
      echo "Error: you must run this script as root" >&2
      exit 4  # According to LSB: 4 - user had insufficient privileges
    fi
    if [ -f "/etc/cassandra/.configured" ]; then
      echo "Cassandra instances already configured."
      exit
    fi
    echo "### Configuring Cassandra..."
    for i in $(seq 1 $instances); do
      # Instance Variables
      conf_dir=/etc/cassandra/node$i
      data_dir=/var/lib/cassandra/node$i
      log_dir=/var/log/cassandra/node$i
      conf_file=$conf_dir/cassandra.yaml
      env_file=$conf_dir/cassandra-env.sh
      jvm_file=$conf_dir/jvm.options
      log_file=$conf_dir/logback.xml
      rackdc_file=$conf_dir/cassandra-rackdc.properties
      intf="eth$(expr $i - 1)"
      ipaddr=$(ifconfig $intf | grep 'inet[^6]' | awk '{print $2}')
      # Build Configuration Directory
      rsync -avr --delete $conf_src/ $conf_dir/
      # Apply Basic Configuration
      sed -r -i "/cluster_name/s/: '.*'/: $cluster_name/" $conf_file
      sed -r -i "/seeds:/s/127.0.0.1/$seed_host/" $conf_file
      sed -r -i "s/^listen_address/#listen_address/" $conf_file
      sed -r -i "s/^rpc_address/#rpc_address/" $conf_file
      sed -r -i "s/^# listen_interface: .*/listen_interface: $intf/" $conf_file
      sed -r -i "s/^# rpc_interface: .*/rpc_interface: $intf/" $conf_file
      sed -r -i "/^endpoint_snitch/s/: .*/: $snitch/" $conf_file
      sed -r -i "/^endpoint_snitch:/a dynamic_snitch: $dynamic_snitch" $conf_file
      sed -r -i "s|hints_directory: .*|hints_directory: $data_dir/hints|" $conf_file
      sed -r -i "s|commitlog_directory: .*|commitlog_directory: $data_dir/commitlog|" $conf_file
      sed -r -i "s|saved_caches_directory: .*|saved_caches_directory: $data_dir/saved_caches|" $conf_file
      sed -r -i "s|/var/lib/cassandra/data|$data_dir/data|" $conf_file
      # Apply Basic Performance Tuning
      cores=$(cat /proc/cpuinfo | grep "^processor" | wc -l)
      cpi=$(expr $cores / $instances)
      sed -r -i "/num_tokens/s/: .*/: $num_tokens/" $conf_file
      sed -r -i "/enable_materialized_views/s/: .*/: false/" $conf_file
      sed -r -i "s/#concurrent_compactors: .*/concurrent_compactors: $cpi/" $conf_file
      # Apply Network Topology (Infer rack from machine's hostname)
      if [[ "$snitch" != "SimpleSnitch" ]]; then
        index=$(hostname | awk '{ print substr($0,length,1) }')
        sed -r -i "/^dc/s/=.*/=$dc_name/" $rackdc_file
        sed -r -i "/^rack/s/=.*/=Rack$index/" $rackdc_file
      fi
      # Enable JMX Access
      sed -r -i "/rmi.server.hostname/s/.public name./$ipaddr/" $env_file
      sed -r -i "/rmi.server.hostname/s/^#//" $env_file
      sed -r -i "/jmxremote.access/s/#//" $env_file
      sed -r -i "/LOCAL_JMX=/s/yes/no/" $env_file
      sed -r -i "/^JMX_PORT/s/7199/7$${i}99/" $env_file
      sed -r -i "s|-Xloggc:.*.log|-Xloggc:$log_dir/gc.log|" $env_file
      # Configure Heap (make sure it is consistent with the available RAM)
      if [[ "$version" != *"3.11"* ]]; then
        jvm_file="$conf_dir/jvm-server.options"
      fi
      total_mem_in_mb=$(free -m | awk '/:/ {print $2;exit}')
      fraction=$(expr $instances \* 2)
      mem_in_mb=$(expr $total_mem_in_mb / $fraction)
      if [[ "$mem_in_mb" -gt "30720" ]]; then
        mem_in_mb="30720"
      fi
      sed -r -i "s/#-Xms4G/-Xms$${mem_in_mb}M/" $jvm_file
      sed -r -i "s/#-Xmx4G/-Xmx$${mem_in_mb}M/" $jvm_file
      # Disable CMSGC and enable G1GC
      if [[ "$version" != *"3.11"* ]]; then
        jvm_file="$conf_dir/jvm11-server.options"
      fi
      ToDisable=(UseParNewGC UseConcMarkSweepGC CMSParallelRemarkEnabled SurvivorRatio MaxTenuringThreshold CMSInitiatingOccupancyFraction UseCMSInitiatingOccupancyOnly CMSWaitDuration CMSParallelInitialMarkEnabled CMSEdenChunksRecordAlways CMSClassUnloadingEnabled)
      for entry in "$${ToDisable[@]}"; do
        sed -r -i "/$entry/s/-XX/#-XX/" $jvm_file
      done
      ToEnable=(UseG1GC G1RSetUpdatingPauseTimePercent MaxGCPauseMillis InitiatingHeapOccupancyPercent ParallelGCThreads)
      for entry in "$${ToEnable[@]}"; do
        sed -r -i "/$entry/s/#-XX/-XX/" $jvm_file
      done
    done
    chown cassandra:cassandra /etc/cassandra/jmxremote.*
    # Make sure that CASSANDRA_CONF is not overriden
    infile=/usr/share/cassandra/cassandra.in.sh
    sed -r -i 's/^CASSANDRA_CONF/#CASSANDRA_CONF/' $infile
    echo 'if [ -z "$CASSANDRA_CONF" ]; then
      CASSANDRA_CONF=/etc/cassandra/conf
    fi' | cat - $infile > /tmp/_temp && mv /tmp/_temp $infile
    # Finish
    systemctl mask cassandra
    touch /etc/cassandra/.configured

- owner: root:root
  permissions: '0400'
  path: /etc/cassandra/jmxremote.password
  content: |
    monitorRole QED
    controlRole R&D
    cassandra cassandra

- owner: root:root
  permissions: '0400'
  path: /etc/cassandra/jmxremote.access
  content: |
    monitorRole readonly
    cassandra   readwrite
    controlRole readwrite \
                create javax.management.monitor.*,javax.management.timer.* \
                unregister

- owner: root:root
  permissions: '0400'
  path: /etc/snmp/snmpd.conf
  content: |
    rocommunity public default
    syslocation Azure
    syscontact IT
    dontLogTCPWrappersConnects yes

packages:
- net-snmp
- net-snmp-utils
- tmux

runcmd:
- sysctl --system
- systemctl daemon-reload
- systemctl enable --now snmpd
- systemctl enable --now disable-thp
- /etc/cassandra/install.sh
- /etc/cassandra/configure_disks.sh
- /etc/cassandra/configure_rsyslog.sh
- /etc/cassandra/configure_cassandra.sh
- /etc/cassandra/bootstrap.sh
