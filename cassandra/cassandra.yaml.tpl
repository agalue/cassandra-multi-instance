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
  path: /etc/cassandra/current-resource-shard.py
  content: |
    #!/usr/bin/env python
    from time import time

    def round_down(num, divisor):
      return num - (num%divisor)

    SHARD = 604800 # see org.opennms.newts.config.resource_shard
    now_ts = time()
    partition = int(round_down(now_ts, SHARD))
    print(partition)

- owner: root:root
  path: /etc/cassandra/fix-schema.cql
  content: |
    ALTER KEYSPACE system_auth WITH REPLICATION = {
      'class' : 'NetworkTopologyStrategy',
      '${dc_name}' : 1
    };

    ALTER KEYSPACE system_distributed WITH REPLICATION = {
      'class' : 'NetworkTopologyStrategy',
      '${dc_name}' : 3
    };

    ALTER KEYSPACE system_traces WITH REPLICATION = {
      'class' : 'NetworkTopologyStrategy',
      '${dc_name}' : 2
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

    # WARNING: This script is designed to be executed once.
    # For SimpleSnitch starts one instance at a time in physical order.
    # For GossipingPropertyFileSnitch starts one instance at a time per server/rack.

    # Global variables overridable via external parameters
    instances="3"
    snitch="GossipingPropertyFileSnitch"
    seed_host="127.0.0.1"

    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
      cat <<EOF
    $0 [options]

    Options:
    --instances  number  The number of Cassandra instances to run on this server [default: $instances]
    --snitch     string  The value for endpoint_snitch [default: $snitch]
    --seed_host  string  The IP address of the seed node [default: $seed_host]
    EOF
      exit
    fi

    # Parse external variables
    while [ $# -gt 0 ]; do
      if [[ $1 == *"--"* ]]; then
        param="$${1/--/}"
        declare $param="$2"
      fi
      shift
    done

    function wait_for_seed {
      until echo -n >/dev/tcp/$seed_host/9042 2>/dev/null; do
        printf '.'
        sleep 10
      done
      echo "done"
    }

    function get_running_instances {
      echo $(nodetool -u cassandra -pw cassandra -h $seed_host status | grep "^UN" | wc -l)
    }

    if [ ! -f "/etc/cassandra/.configured" ]; then
      echo "Error: the Cassandra instances have not been configured. Please run /etc/cassandra/configure_cassandra.sh"
      exit 1
    fi

    if [ "$(id -u -n)" != "root" ]; then
      echo "Error: you must run this script as root" >&2
      exit 4  # According to LSB: 4 - user had insufficient privileges
    fi

    re='^[0-9]+$'
    available=$(ip a | grep "^[0-9]: eth" | wc -l)
    if ! [[ $instances =~ $re ]] || [[ $instances > $available ]] || [[ $instances < 1 ]]; then
      echo "Error: please provide a number of instances between 1 and $available"
      exit 1
    fi

    if [[ "$seed_host" == "127.0.0.1" ]]; then
      echo "Error: please specify with seed_host."
      exit 1
    fi

    # Ensure the init.d version is not usable by an operator
    systemctl mask cassandra
    systemctl daemon-reload

    echo "Bootstrapping Cassandra..."

    j=$(hostname | awk '{ print substr($0,length,1) }')

    required_instances=0
    if [[ "$snitch" != "SimpleSnitch" ]]; then
      required_instances=$(($j - 1))
    fi

    for i in $(seq 1 $instances); do
      echo "Bootstrapping instance $i from server $j..."
      if [[ "$j" == "1" ]] && [[ "$i" == "1" ]]; then

        # Processing seed node (the first instance of the first server)
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

        # Processing non-seed nodes
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

    # Global variables overridable via external parameters
    version="latest"

    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
      cat <<EOF
    $0 [options]

    Options:
    --version  string  The version of Cassandra to use [default: $version]
                       For instance: 3.11.10, 4.0.1 or latest.
    EOF
      exit
    fi

    # Parse external variables
    while [ $# -gt 0 ]; do
      if [[ $1 == *"--"* ]]; then
        param="$${1/--/}"
        declare $param="$2"
      fi
      shift
    done

    if [ "$(id -u -n)" != "root" ]; then
      echo "Error: you must run this script as root" >&2
      exit 4  # According to LSB: 4 - user had insufficient privileges
    fi

    repo_ver=""
    if [[ "$version" == *"3.11."* ]]; then
      repo_ver="311x"
    fi
    if [[ "$version" == *"4.0."* ]] || [[ "$version" == "latest" ]]; then
      repo_ver="40x"
    fi
    if [[ "$repo_ver" == "" ]]; then
      echo "Error: only Cassandra 3.11.x or 4.0.x are supported".
      exit 1
    fi

    # The archive repository contains all versions of Cassandra
    repo_base="https://archive.apache.org/dist/cassandra"

    echo "Installing/Upgrading Cassandra..."

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

    # Global variables overridable via external parameters
    instances="3"

    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
      cat <<EOF
    $0 [options]

    Options:
    --instances  number  The number of Cassandra instances to run on this server [default: $instances]
    EOF
      exit
    fi

    # Parse external variables
    while [ $# -gt 0 ]; do
      if [[ $1 == *"--"* ]]; then
        param="$${1/--/}"
        declare $param="$2"
      fi
      shift
    done

    if [[ "$(id -u -n)" != "root" ]]; then
      echo "Error: you must run this script as root" >&2
      exit 4  # According to LSB: 4 - user had insufficient privileges
    fi

    re='^[0-9]+$'
    available=$(ip a | grep "^[0-9]: eth" | wc -l)
    if ! [[ $instances =~ $re ]] || [[ $instances > $available ]] || [[ $instances < 1 ]]; then
      echo "Error: please provide a number of instances between 1 and $available"
      exit 1
    fi

    directories=("commitlog" "data" "hints" "saved_caches")
    data_location=/var/lib/cassandra
    log_location=/var/log/cassandra

    if [ ! -f "/etc/fstab.bak" ]; then
      cp /etc/fstab /etc/fstab.bak
    fi

    echo "Waiting for $instances disks to be available"
    while [ $(ls -l /dev/disk/azure/scsi1 | grep lun | wc -l) -lt $instances ]; do
      printf '.'
      sleep 10
    done

    echo "Configuring Cassandra Data Disks..."
    for i in $(seq 1 $instances); do
      disk=$(readlink -f /dev/disk/azure/scsi1/lun$(expr $i - 1))
      dev=$${disk}1
      mount_point=/data/node$i

      echo "Waiting for $disk to be ready"
      while [ ! -e $disk ]; do
        printf '.'
        sleep 10
      done

      if [ -e $dev ]; then
        # This script was designed to be executed once per disk device
        echo "Device $dev (disk $i) already configured and formatted"
      else
        echo "Formatting $disk (disk $i)"
        echo ';' | sfdisk $disk
        mkfs -t xfs -f $dev
      fi

      mkdir -p $mount_point
      if grep -qs $mount_point /proc/mounts; then
        echo "$dev (disk $i) already mounted at $mount_point"
      else
        echo "Mounting $dev (disk $i) at $mount_point"
        echo "$dev $mount_point xfs defaults,noatime 0 0" >> /etc/fstab
        mount $mount_point
      fi

      location=$data_location/node$i
      if [ -L $location ]; then
        echo "Data directory for $dev (disk $i) already configured"
      else
        echo "Configuring data directory for $dev (disk $i)"
        ln -s /data/node$i $location
        for dir in "$${directories[@]}"; do
          mkdir -p $location/$dir
        done
        chown -R cassandra:cassandra $mount_point
      fi

      log_dir=$log_location/node$i
      if [ -e $log_dir ]; then
        echo "Log directory for $dev (disk $i) already configured"
      else
        echo "Configuring log directory for $dev (disk $i)"
        mkdir -p $log_dir
        chown -R cassandra:cassandra log_dir
      fi

      if grep -qs $mount_point /etc/snmp/snmpd.conf; then
        echo "SNMP monitoring for $mount_point (disk $i) already configured"
      else
        echo "Configuring SNMP monitoring for $mount_point (disk $i)"
        echo "disk $mount_point" >> /etc/snmp/snmpd.conf
      fi
    done

    # Remove original data directories
    for dir in "$${directories[@]}"; do
      rm -rf $data_location/$dir
    done

    systemctl restart snmpd

- owner: root:root
  permissions: '0750'
  path: /etc/cassandra/configure_rsyslog.sh
  content: |
    #!/bin/bash

    # Global variables overridable via external parameters
    instances="3"

    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
      cat <<EOF
    $0 [options]

    Options:
    --instances  number  The number of Cassandra instances to run on this server [default: $instances]
    EOF
      exit
    fi

    # Parse external variables
    while [ $# -gt 0 ]; do
      if [[ $1 == *"--"* ]]; then
        param="$${1/--/}"
        declare $param="$2"
      fi
      shift
    done

    if [[ "$(id -u -n)" != "root" ]]; then
      echo "Error: you must run this script as root" >&2
      exit 4  # According to LSB: 4 - user had insufficient privileges
    fi

    re='^[0-9]+$'
    available=$(ip a | grep "^[0-9]: eth" | wc -l)
    if ! [[ $instances =~ $re ]] || [[ $instances > $available ]] || [[ $instances < 1 ]]; then
      echo "Error: please provide a number of instances between 1 and $available"
      exit 1
    fi

    echo "Configuring rsyslog..."
    rsyslog_file=/etc/rsyslog.d/cassandra.conf
    rm -f $rsyslog_file
    for i in $(seq 1 $instances); do
      id=cassandra-node$i
      log=/var/log/cassandra/node$i/cassandra.log
      echo "if \$programname == '$id' then $log" >> $rsyslog_file
    done

    systemctl restart rsyslog

- owner: root:root
  permissions: '0750'
  path: /etc/cassandra/configure_cassandra.sh
  content: |
    #!/bin/bash

    # Global variables overridable via external parameters
    cluster_name="OpenNMS Cluster"
    snitch="GossipingPropertyFileSnitch"
    dynamic_snitch="true"
    num_tokens="16"
    seed_host="127.0.0.1"
    dc_name="DC1"
    instances="3"

    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
      cat <<EOF
    $0 [options]

    Options:
    --instances      number  The number of Cassandra instances to run on this server [default: $instances]
    --cluster_name   string  The name of the Cassandra cluster [default: $cluster_name]
                             Must be the same for all its members
    --snitch         string  The value for endpoint_snitch [default: $snitch]
                             Must be the same for all its members
    --num_tokens     string  The number of tokens for vnodes [default: $num_tokens]
                             Must be the same for all its members
    --dynamic_snitch bool    true to enable dynamic snitch, false otherwise [default: $dynamic_snitch]
    --seed_host      string  The IP address of the seed node [default: $seed_host]
    --dc_name        string  The name of the Datacenter to use when using NTS [default: $dc_name]
    EOF
      exit
    fi

    # Parse external variables
    while [ $# -gt 0 ]; do
      if [[ $1 == *"--"* ]]; then
        param="$${1/--/}"
        declare $param="$2"
      fi
      shift
    done

    # Extracts the last digit from the hostname and use it to define the rack
    # Alternatively, you can use the hostname as the rack name
    function get_rack {
      index=$(hostname | awk '{ print substr($0,length,1) }')
      return "Rack$index"
    }

    if [ -f "/etc/cassandra/.configured" ]; then
      echo "Warning: cassandra instances already configured."
      exit
    fi

    if [[ "$(id -u -n)" != "root" ]]; then
      echo "Error: you must run this script as root" >&2
      exit 4  # According to LSB: 4 - user had insufficient privileges
    fi

    re='^[0-9]+$'
    available=$(ip a | grep "^[0-9]: eth" | wc -l)
    if ! [[ $instances =~ $re ]] || [[ $instances > $available ]] || [[ $instances < 1 ]]; then
      echo "Error: please provide a number of instances between 1 and $available"
      exit 1
    fi

    if [[ "$seed_host" == "127.0.0.1" ]]; then
      echo "Error: please specify with seed_host."
      exit 1
    fi

    version=$(rpm -q --queryformat '%%{VERSION}' cassandra)
    conf_src=/etc/cassandra/conf

    echo "Configuring $instances instances of Cassandra..."
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

      echo "Configuring Cassandra Instance $i ($intf : $ipaddr)..."

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
        sed -r -i "/^rack/s/=.*/=$(get_rack)/" $rackdc_file
      fi

      # Enable JMX Access
      sed -r -i "/rmi.server.hostname/s/.public name./$ipaddr/" $env_file
      sed -r -i "/rmi.server.hostname/s/^#//" $env_file
      sed -r -i "/jmxremote.access/s/#//" $env_file
      sed -r -i "/LOCAL_JMX=/s/yes/no/" $env_file
      sed -r -i "/^JMX_PORT/s/7199/7$${i}99/" $env_file
      sed -r -i "s|-Xloggc:.*.log|-Xloggc:$log_dir/gc.log|" $env_file

      # Calculate suggested heap size
      total_mem_in_mb=$(free -m | awk '/:/ {print $2;exit}')
      fraction=$(expr $instances \* 2)
      mem_in_mb=$(expr $total_mem_in_mb / $fraction)
      if [[ "$mem_in_mb" -gt "30720" ]]; then
        mem_in_mb="30720"
      fi

      # Configure Heap (make sure it is consistent with the available RAM)
      if [[ "$version" != *"3.11"* ]]; then
        jvm_file="$conf_dir/jvm-server.options"
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
  permissions: '0755'
  path: /etc/cassandra/set_compaction_throughput.sh
  content: |
    #!/bin/bash

    # External Variables
    throughput="200"
    instances="3"

    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
      cat <<EOF
    $0 [options]

    Options:
    --instances  number  The number of Cassandra instances to run on this server [default: $instances]
    --throughput number  The desired throughput in Mbps [default: $throughput]
    EOF
      exit
    fi

    # Parse external variables
    while [ $# -gt 0 ]; do
      if [[ $1 == *"--"* ]]; then
        param="$${1/--/}"
        declare $param="$2"
      fi
      shift
    done

    re='^[0-9]+$'
    available=$(ip a | grep "^[0-9]: eth" | wc -l)
    if ! [[ $instances =~ $re ]] || [[ $instances > $available ]] || [[ $instances < 1 ]]; then
      echo "Error: please provide a number of instances between 1 and $available"
      exit 1
    fi

    for i in $(seq 1 $instances); do
      intf="eth$(expr $i - 1)"
      ipaddr=$(ifconfig $intf | grep 'inet[^6]' | awk '{print $2}')
      nodetool -u cassandra -pw cassandra -h $ipaddr -p 7$${i}99 setstreamthroughput -- $throughput
    done

- owner: root:root
  permissions: '0755'
  path: /etc/cassandra/nodetool.sh
  content: |
    #!/bin/bash

    # External Variables
    instance=""

    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
      cat <<EOF
    $0 [options] [nodetool commands and arguments]

    Options:
    --instance  number  The ID of the target Cassandra instance to use with the nodetool command

    Examples:
    $0 --instance 1 status
    $0 --instance 2 setstreamthroughput 400
    EOF
      exit
    fi

    # Parse external variables
    if [[ $1 == *"--"* ]]; then
      param="$${1/--/}"
      declare $param="$2"
    fi
    shift
    shift

    re='^[0-9]+$'
    available=$(ip a | grep "^[0-9]: eth" | wc -l)
    if ! [[ $instance =~ $re ]] || [[ $instance > $available ]] || [[ $instance < 1 ]]; then
      echo "Error: please provide an instance number between 1 and $available"
      exit 1
    fi

    intf="eth$(expr $instance - 1)"
    ipaddr=$(ifconfig $intf | grep 'inet[^6]' | awk '{print $2}')

    echo "Instance $instance"
    echo "Issuing nodetool -h $ipaddr -p 7$${instance}99 $@"
    nodetool -u cassandra -pw cassandra -h $ipaddr -p 7$${instance}99 $@

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
- /etc/cassandra/install.sh --version ${version}
- /etc/cassandra/configure_disks.sh --instances ${number_of_instances}
- /etc/cassandra/configure_rsyslog.sh --instances ${number_of_instances}
- /etc/cassandra/configure_cassandra.sh  --instances ${number_of_instances} --cluster_name "${cluster_name}" --snitch ${endpoint_snitch} --dynamic_snitch ${dynamic_snitch} --num_tokens ${num_tokens} --seed_host "${seed_host}" --dc_name "${dc_name}"
- /etc/cassandra/bootstrap.sh --instances ${number_of_instances} --snitch ${endpoint_snitch} --seed_host "${seed_host}"
