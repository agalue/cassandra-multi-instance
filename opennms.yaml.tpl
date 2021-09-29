package_upgrade: false
timezone: America/New_York

write_files:
- owner: root:root
  path: /opt/opennms-etc-overlay/default-foreign-source.xml
  content: |
    <foreign-source xmlns="http://xmlns.opennms.org/xsd/config/foreign-source" name="default" date-stamp="2021-03-31T00:00:00.000Z">
      <scan-interval>1d</scan-interval>
      <detectors>
        <detector name="ICMP" class="org.opennms.netmgt.provision.detector.icmp.IcmpDetector"/>
        <detector name="SNMP" class="org.opennms.netmgt.provision.detector.snmp.SnmpDetector"/>
      </detectors>
      <policies>
        <policy name="NoDiscoveredIPs" class="org.opennms.netmgt.provision.persist.policies.MatchingIpInterfacePolicy">
          <parameter key="action" value="DO_NOT_PERSIST"/>
          <parameter key="matchBehavior" value="NO_PARAMETERS"/>
        </policy>
        <policy name="DataCollection" class="org.opennms.netmgt.provision.persist.policies.MatchingSnmpInterfacePolicy">
          <parameter key="action" value="ENABLE_COLLECTION"/>
          <parameter key="matchBehavior" value="ANY_PARAMETER"/>
          <parameter key="ifOperStatus" value="1"/>
        </policy>
      </policies>
    </foreign-source>

- owner: root:root
  path: /opt/opennms-etc-overlay/jmx-datacollection-config.d/cassandra30x-newts.xml
  content: |
    <?xml version="1.0"?>
    <jmx-datacollection-config>
      <jmx-collection name="jmx-cassandra30x-newts">
        <rrd step="30">
          <rra>RRA:AVERAGE:0.5:1:2016</rra>
        </rrd>
        <mbeans>
          <!-- Newts :: AllMemmtables -->
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=AllMemtablesLiveDataSize">
            <attrib name="Value" alias="alMemTblLiDaSi" type="gauge"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=AllMemtablesOffHeapDataSize">
            <attrib name="Value" alias="alMemTblOffHeapDaSi" type="gauge"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=AllMemtablesOnHeapDataSize">
            <attrib name="Value" alias="alMemTblOnHeapDaSi" type="gauge"/>
          </mbean>
          <!-- Memtable :: Count -->
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=MemtableSwitchCount">
            <attrib name="Value" alias="memTblSwitchCount" type="counter"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=MemtableColumnsCount">
            <attrib name="Value" alias="memTblColumnsCnt" type="gauge"/>
          </mbean>
          <!-- Memtable :: Sizes -->
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=MemtableLiveDataSize">
            <attrib name="Value" alias="memTblLiveDaSi" type="gauge"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=MemtableOffHeapDataSize">
            <attrib name="Value" alias="memTblOffHeapDaSi" type="gauge"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=MemtableOnHeapDataSize">
            <attrib name="Value" alias="memTblOnHeapDaSi" type="gauge"/>
          </mbean>
          <!-- Latency -->
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=ReadTotalLatency">
            <attrib name="Count" alias="readTotLtncy" type="counter"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=RangeLatency">
            <attrib name="99thPercentile" alias="rangeLtncy99" type="gauge"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=WriteTotalLatency">
            <attrib name="Count" alias="writeTotLtncy" type="counter"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=CasCommitTotalLatency">
            <attrib name="Count" alias="casCommitTotLtncy" type="counter"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=CasPrepareTotalLatency">
            <attrib name="Count" alias="casPrepareTotLtncy" type="counter"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=CasProposeTotalLatency">
            <attrib name="Count" alias="casProposeTotLtncy" type="counter"/>
          </mbean>
          <!-- Bloom Filter -->
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=BloomFilterDiskSpaceUsed">
            <attrib name="Value" alias="blmFltrDskSpcUsed" type="gauge"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=BloomFilterOffHeapMemoryUsed">
            <attrib name="Value" alias="blmFltrOffHeapMemUs" type="gauge"/>
          </mbean>
          <!-- Memory Used -->
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=CompressionMetadataOffHeapMemoryUsed">
            <attrib name="Value" alias="cmpMetaOffHeapMemUs" type="gauge"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=IndexSummaryOffHeapMemoryUsed">
            <attrib name="Value" alias="idxSumOffHeapMemUs" type="gauge"/>
          </mbean>
          <!-- Pending -->
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=PendingCompactions">
            <attrib name="Value" alias="pendingCompactions" type="gauge"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=PendingFlushes">
            <attrib name="Value" alias="pendingFlushes" type="gauge"/>
          </mbean>
          <!-- Disk Space -->
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=TotalDiskSpaceUsed">
            <attrib name="Value" alias="totalDiskSpaceUsed" type="gauge"/>
          </mbean>
          <mbean name="org.apache.cassandra.metrics.Keyspace" resource-type="cassKeyspace"
            objectname="org.apache.cassandra.metrics:type=Keyspace,keyspace=*newts*,name=LiveDiskSpaceUsed">
            <attrib name="Value" alias="liveDiskSpaceUsed" type="gauge"/>
          </mbean>
        </mbeans>
      </jmx-collection>
    </jmx-datacollection-config>

- owner: root:root
  path: /opt/opennms-etc-overlay/org.opennms.features.datachoices.cfg
  content: |
    enabled=false
    acknowledged-by=admin
    acknowledged-at=Mon Jan 01 00\:00\:00 EDT 2021

- owner: root:root
  path: /opt/opennms-etc-overlay/resource-types.d/cassandra-keyspaces.xml
  content: |
    <resource-types>
      <resourceType name="cassKeyspace" label="Cassandra Keyspace" resourceLabel="$${index}">
        <persistenceSelectorStrategy class="org.opennms.netmgt.collection.support.PersistAllSelectorStrategy"/>
        <storageStrategy class="org.opennms.netmgt.dao.support.SiblingColumnStorageStrategy">
          <parameter key="sibling-column-name" value="keyspace" />
        </storageStrategy>
      </resourceType>
    </resource-types>

- owner: root:root
  path: /opt/opennms-etc-overlay/opennms.properties.d/rrd.properties
  content: |
    org.opennms.rrd.storeByGroup=true
    org.opennms.rrd.storeByForeignSource=true

- owner: root:root
  path: /opt/opennms-etc-overlay/opennms.properties.d/newts.properties
  content: |
    org.opennms.timeseries.strategy=newts
    org.opennms.newts.config.hostname=${cassandra_seed}
    org.opennms.newts.config.keyspace=${newts_keyspace}
    org.opennms.newts.config.port=9042
    org.opennms.newts.config.read_consistency=ONE
    org.opennms.newts.config.write_consistency=ANY
    org.opennms.newts.config.resource_shard=${newts_resource_shard}
    org.opennms.newts.config.ttl=${newts_ttl}
    org.opennms.newts.config.cache.priming.enable=true
    org.opennms.newts.config.cache.priming.block_ms=60000
    # The following settings most be tuned in production
    org.opennms.newts.config.writer_threads=2
    org.opennms.newts.config.ring_buffer_size=${ring_buffer_size}
    org.opennms.newts.config.cache.max_entries=${cache_max_entries}
    # For collecting data every 30 seconds from OpenNMS and Cassandra
    org.opennms.newts.query.minimum_step=30000
    org.opennms.newts.query.heartbeat=450000

- owner: root:root
  path: /opt/opennms-etc-overlay/opennms.conf
  content: |
    START_TIMEOUT=0
    JAVA_HEAP_SIZE=2048
    MAXIMUM_FILE_DESCRIPTORS=204800
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -Djava.net.preferIPv4Stack=true"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -Xlog:gc:/opt/opennms/logs/gc.log"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:+UseStringDeduplication"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:+UseG1GC"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:G1RSetUpdatingPauseTimePercent=5"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:MaxGCPauseMillis=500"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:InitiatingHeapOccupancyPercent=70"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:ParallelGCThreads=1"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:ConcGCThreads=1"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:+ParallelRefProcEnabled"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:+AlwaysPreTouch"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:+UseTLAB"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:+ResizeTLAB"
    ADDITIONAL_MANAGER_OPTIONS="$ADDITIONAL_MANAGER_OPTIONS -XX:-UseBiasedLocking"

- owner: root:root
  permissions: '0755'
  path: /tmp/configure-jmx.sh
  content: |
    #!/bin/bash
    cassandra_instances=${cassandra_instances}
    cfg=/opt/opennms/etc/poller-configuration.xml
    cat <<EOF > $cfg
    <poller-configuration xmlns="http://xmlns.opennms.org/xsd/config/poller" threads="30" nextOutageId="SELECT nextval('outageNxtId')" serviceUnresponsiveEnabled="false" pathOutageEnabled="false">
      <node-outage status="on" pollAllIfNoCriticalServiceDefined="true">
        <critical-service name="ICMP"/>
      </node-outage>
      <package name="main">
        <filter>IPADDR != '0.0.0.0'</filter>
        <include-range begin="1.1.1.1" end="254.254.254.254"/>
        <rrd step="30">
          <rra>RRA:AVERAGE:0.5:1:2016</rra>
          <rra>RRA:AVERAGE:0.5:12:1488</rra>
          <rra>RRA:AVERAGE:0.5:288:366</rra>
          <rra>RRA:MAX:0.5:288:366</rra>
          <rra>RRA:MIN:0.5:288:366</rra>
        </rrd>
        <service name="ICMP" interval="30000" user-defined="false" status="on">
          <parameter key="retry" value="2"/>
          <parameter key="timeout" value="3000"/>
          <parameter key="rrd-repository" value="/opt/opennms/share/rrd/response"/>
          <parameter key="rrd-base-name" value="icmp"/>
          <parameter key="ds-name" value="icmp"/>
        </service>
        <service name="OpenNMS-JVM" interval="30000" user-defined="false" status="on">
          <parameter key="port" value="18980"/>
          <parameter key="retry" value="2"/>
          <parameter key="timeout" value="3000"/>
          <parameter key="rrd-repository" value="/opt/opennms/share/rrd/response"/>
        </service>
        <downtime begin="0" end="300000" interval="30000"/><!-- 30s, 0, 5m -->
        <downtime begin="300000" end="43200000" interval="300000"/><!-- 5m, 5m, 12h -->
        <downtime begin="43200000" end="432000000" interval="600000"/><!-- 10m, 12h, 5d -->
        <downtime begin="432000000" interval="3600000"/><!-- 1h, 5d -->
      </package>
      <package name="cassandra-via-jmx">
        <filter>IPADDR != '0.0.0.0'</filter>
        <rrd step="30">
          <rra>RRA:AVERAGE:0.5:1:2016</rra>
        </rrd>
    EOF
    for i in $(seq 1 $cassandra_instances); do
      cat <<EOF >> $cfg
        <service name="JMX-Cassandra-I$i" interval="30000" user-defined="false" status="on">
          <parameter key="port" value="7$${i}99"/>
          <parameter key="retry" value="2"/>
          <parameter key="timeout" value="3000"/>
          <parameter key="banner" value="*"/>
          <parameter key="rrd-base-name" value="jmx-cass-i1"/>
          <parameter key="ds-name" value="jmx-cass-i1"/>
          <parameter key="rrd-repository" value="/opt/opennms/share/rrd/response"/>
        </service>
        <service name="JMX-Cassandra-Newts-I$i" interval="30000" user-defined="false" status="on">
          <parameter key="port" value="7$${i}99"/>
          <parameter key="retry" value="2"/>
          <parameter key="timeout" value="3000"/>
          <parameter key="protocol" value="rmi"/>
          <parameter key="urlPath" value="/jmxrmi"/>
          <parameter key="thresholding-enabled" value="true"/>
          <parameter key="factory" value="PASSWORD-CLEAR"/>
          <parameter key="username" value="cassandra"/>
          <parameter key="password" value="cassandra"/>
          <parameter key="beans.samples" value="org.apache.cassandra.db:type=ColumnFamilies,keyspace=${newts_keyspace},columnfamily=samples"/>
          <parameter key="tests.samples" value="samples.ColumnFamilyName == 'samples'"/>
          <parameter key="beans.terms" value="org.apache.cassandra.db:type=ColumnFamilies,keyspace=${newts_keyspace},columnfamily=terms"/>
          <parameter key="tests.terms" value="terms.ColumnFamilyName == 'terms'"/>
          <parameter key="beans.resource_attributes" value="org.apache.cassandra.db:type=ColumnFamilies,keyspace=${newts_keyspace},columnfamily=resource_attributes"/>
          <parameter key="tests.resource_attributes" value="resource_attributes.ColumnFamilyName == 'resource_attributes'"/>
          <parameter key="beans.resource_metrics" value="org.apache.cassandra.db:type=ColumnFamilies,keyspace=${newts_keyspace},columnfamily=resource_metrics"/>
          <parameter key="tests.resource_metrics" value="resource_metrics.ColumnFamilyName == 'resource_metrics'"/>
          <parameter key="rrd-base-name" value="jmx-cass-newts-i1"/>
          <parameter key="ds-name" value="jmx-cass-newts-i1"/>
          <parameter key="rrd-repository" value="/opt/opennms/share/rrd/response"/>
        </service>
    EOF
    done
      cat <<EOF >> $cfg
        <downtime begin="0" end="300000" interval="30000"/><!-- 30s, 0, 5m -->
        <downtime begin="300000" end="43200000" interval="300000"/><!-- 5m, 5m, 12h -->
        <downtime begin="43200000" end="432000000" interval="600000"/><!-- 10m, 12h, 5d -->
        <downtime begin="432000000" interval="3600000"/><!-- 1h, 5d -->
      </package>
      <monitor service="ICMP" class-name="org.opennms.netmgt.poller.monitors.IcmpMonitor"/>
      <monitor service="OpenNMS-JVM" class-name="org.opennms.netmgt.poller.monitors.Jsr160Monitor"/>
    EOF
    for i in $(seq 1 $cassandra_instances); do
      cat <<EOF >> $cfg
      <monitor service="JMX-Cassandra-I$i" class-name="org.opennms.netmgt.poller.monitors.TcpMonitor"/>
      <monitor service="JMX-Cassandra-Newts-I$i" class-name="org.opennms.netmgt.poller.monitors.Jsr160Monitor"/>
    EOF
    done
    cat <<EOF >> $cfg
    </poller-configuration>
    EOF
    cfg=/opt/opennms/etc/collectd-configuration.xml
    cat <<EOF > $cfg
    <collectd-configuration xmlns="http://xmlns.opennms.org/xsd/config/collectd" threads="50">
      <package name="main" remote="false">
        <filter>IPADDR != '0.0.0.0'</filter>
        <include-range begin="1.1.1.1" end="254.254.254.254"/>
        <service name="SNMP" interval="30000" user-defined="false" status="on">
          <parameter key="collection" value="default"/>
          <parameter key="thresholding-enabled" value="true"/>
        </service>
        <service name="OpenNMS-JVM" interval="30000" user-defined="false" status="on">
          <parameter key="port" value="18980"/>
          <parameter key="retry" value="2"/>
          <parameter key="timeout" value="3000"/>
          <parameter key="collection" value="jsr160"/>
          <parameter key="friendly-name" value="opennms-jvm"/>
          <parameter key="thresholding-enabled" value="true"/>
          <parameter key="factory" value="PASSWORD-CLEAR"/>
          <parameter key="username" value="admin"/>
          <parameter key="password" value="admin"/>
        </service>
        <service name="PostgreSQL" interval="30000" user-defined="false" status="on">
          <parameter key="collection" value="PostgreSQL"/>
          <parameter key="thresholding-enabled" value="true"/>
          <parameter key="driver" value="org.postgresql.Driver"/>
          <parameter key="user" value="postgres"/>
          <parameter key="password" value="postgres"/>
          <parameter key="url" value="jdbc:postgresql://OPENNMS_JDBC_HOSTNAME:5432/opennms"/>
        </service>
      </package>
      <package name="cassandra-via-jmx" remote="false">
        <filter>IPADDR != '0.0.0.0'</filter>
    EOF
    for i in $(seq 1 $cassandra_instances); do
      cat <<EOF >> $cfg
        <service name="JMX-Cassandra-I$i" interval="30000" user-defined="false" status="on">
          <parameter key="port" value="7$${i}99"/>
          <parameter key="retry" value="2"/>
          <parameter key="timeout" value="3000"/>
          <parameter key="protocol" value="rmi"/>
          <parameter key="urlPath" value="/jmxrmi"/>
          <parameter key="collection" value="jmx-cassandra30x"/>
          <parameter key="friendly-name" value="cassandra-instance1"/>
          <parameter key="thresholding-enabled" value="true"/>
          <parameter key="factory" value="PASSWORD-CLEAR"/>
          <parameter key="username" value="cassandra"/>
          <parameter key="password" value="cassandra"/>
        </service>
        <service name="JMX-Cassandra-Newts-I$i" interval="30000" user-defined="false" status="on">
          <parameter key="port" value="7$${i}99"/>
          <parameter key="retry" value="2"/>
          <parameter key="timeout" value="3000"/>
          <parameter key="protocol" value="rmi"/>
          <parameter key="urlPath" value="/jmxrmi"/>
          <parameter key="collection" value="jmx-cassandra30x-newts"/>
          <parameter key="friendly-name" value="cassandra-newts-instance2"/>
          <parameter key="thresholding-enabled" value="true"/>
          <parameter key="factory" value="PASSWORD-CLEAR"/>
          <parameter key="username" value="cassandra"/>
          <parameter key="password" value="cassandra"/>
        </service>
    EOF
    done
    cat <<EOF >> $cfg
      </package>
      <collector service="PostgreSQL" class-name="org.opennms.netmgt.collectd.JdbcCollector"/>
      <collector service="SNMP" class-name="org.opennms.netmgt.collectd.SnmpCollector"/>
      <collector service="OpenNMS-JVM" class-name="org.opennms.netmgt.collectd.Jsr160Collector"/>
    EOF
    for i in $(seq 1 $cassandra_instances); do
      cat <<EOF >> $cfg
      <collector service="JMX-Cassandra-I$i" class-name="org.opennms.netmgt.collectd.Jsr160Collector"/>
      <collector service="JMX-Cassandra-Newts-I$i" class-name="org.opennms.netmgt.collectd.Jsr160Collector"/>
    EOF
    done
    cat <<EOF >> $cfg
    </collectd-configuration>
    EOF

- owner: root:root
  permissions: '0755'
  path: /tmp/setup.sh
  content: |
    #!/bin/bash
    if rpm -qa | grep -q opennms-core; then
      echo "OpenNMS is already installed."
      exit
    fi
    . /etc/os-release
    echo "Installing and configuring PostgreSQL"
    yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$VERSION_ID-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    if [[ "$VERSION_ID" == "8" ]]; then
      dnf -qy module disable postgresql
    fi
    yum install -y postgresql12-server
    /usr/pgsql-12/bin/postgresql-12-setup initdb
    sed -r -i "/^(local|host)/s/(peer|ident)/trust/g" /var/lib/pgsql/12/data/pg_hba.conf
    systemctl --now enable postgresql-12
    echo "Installing and configuring OpenNMS"
    yum install -y https://yum.opennms.org/repofiles/opennms-repo-stable-rhel$VERSION_ID.noarch.rpm
    yum install -y opennms-core opennms-webapp-jetty opennms-webapp-hawtio
    rsync -avr /opt/opennms-etc-overlay/ /opt/opennms/etc/
    num_cores=$(cat /proc/cpuinfo | grep "^processor" | wc -l)
    half_cores=$(expr $num_cores / 2)
    total_mem_in_mb=$(free -m | awk '/:/ {print $2;exit}')
    mem_in_mb=$(expr $total_mem_in_mb / 2)
    if [[ "$mem_in_mb" -gt "30720" ]]; then
      mem_in_mb="30720"
    fi
    sed -r -i "/JAVA_HEAP_SIZE/s/=.*/=$mem_in_mb/" /opt/opennms/etc/opennms.conf
    sed -r -i "/GCThreads=/s/1/$half_cores/" /opt/opennms/etc/opennms.conf
    sed -r -i "/writer_threads=/s/2/$num_cores/" /opt/opennms/etc/opennms.properties.d/newts.properties
    sed -r -i "s/=interfaceSnmp/=cassKeyspace" /opt/opennms/etc/snmp-graph.properties.d/cassandra-newts-graph.properties
    # Monitor and collect metrics every 30 seconds from OpenNMS and Cassandra
    files=($(ls -l /opt/opennms/etc/*datacollection-config.xml | awk '{print $9}'))
    files+=($(ls -l /opt/opennms/etc/jmx-datacollection-config.d/*.xml | awk '{print $9}'))
    for f in "$${files[@]}"; do
      if [ -f $f ]; then
        sed -r -i 's/step="300"/step="30"/g' $f
      fi
    done
    echo "Waiting for Cassandra"
    until echo -n >/dev/tcp/${cassandra_seed}/9042 2>/dev/null; do
      printf '.'
      sleep 10
    done
    echo "done"
    echo "Starting OpenNMS"
    /opt/opennms/bin/runjava -s
    /opt/opennms/bin/install -dis
    systemctl --now enable opennms

- owner: root:root
  permissions: '0755'
  path: /tmp/requisition.sh
  content: |
    #!/bin/bash
    servers=${cassandra_vms}
    instances=${cassandra_instances}
    IFS=',' read -r -a addresses <<< "${cassandra_addresses}"
    req=/tmp/Infrastructure.xml
    ipaddr=$(ifconfig eth0 | grep 'inet[^6]' | awk '{print $2}')
    cat <<EOF > $req
    <model-import xmlns="http://xmlns.opennms.org/xsd/config/model-import" date-stamp="2018-04-01T11:00:00.000-04:00" foreign-source="Infrastructure">
      <node building="us-east-2" foreign-id="opennms" node-label="opennms-server">
        <interface descr="eth0" ip-addr="$ipaddr" status="1" snmp-primary="P"/>
        <interface descr="loopback" ip-addr="127.0.0.1" status="1" snmp-primary="N">
          <monitored-service service-name="OpenNMS-JVM"/>
          <monitored-service service-name="PostgreSQL"/>
        </interface>
      </node>
    EOF
    for i in $(seq 1 $servers); do
      cat <<EOF >> $req
      <node foreign-id="cassandra$i" node-label="cassandra$i">
    EOF
      intf=1
      primary="P"
      for ip in "$${addresses[@]}"; do
        IFS='.' read -r -a octets <<< "$ip"
        if [[ $${octets[3]} =~ ^$i.* ]] && [[ $intf -le $instances ]]; then
          cat <<EOF >> $req
        <interface descr="eth$((intf-1))" ip-addr="$ip" status="1" snmp-primary="$primary">
          <monitored-service service-name="JMX-Cassandra-I$intf"/>
          <monitored-service service-name="JMX-Cassandra-Newts-I$intf"/>
        </interface>
    EOF
          intf=$((intf+1))
          primary="N"
        fi
      done
      cat <<EOF >> $req
      </node>
    EOF
    done
    cat <<EOF >> $req
    </model-import>
    EOF
    echo "Waiting for OpenNMS to be ready"
    url=http://localhost:8980/opennms
    until $(curl --output /dev/null --silent --head --fail $url/login.jsp); do
      printf '.'
      sleep 5
    done
    curl -u admin:admin -H 'Content-Type: application/xml' -d @$req $url/rest/requisitions
    curl -u admin:admin -H 'Content-Type: application/xml' -X PUT $url/rest/requisitions/Infrastructure/import
done

- owner: root:root
  permissions: '0400'
  path: /etc/snmp/snmpd.conf
  content: |
    rocommunity public default
    syslocation Azure - ${location}
    syscontact ${user}
    dontLogTCPWrappersConnects yes
    disk /

packages:
- net-snmp
- net-snmp-utils
- epel-release
- java-11-openjdk-devel

runcmd:
- sysctl --system
- systemctl enable --now snmpd
- yum install -y haveged
- systemctl --now enable haveged
- /tmp/setup.sh
- /tmp/configure-jmx.sh
- /tmp/requisition.sh
