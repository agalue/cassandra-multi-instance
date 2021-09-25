# cassandra-multi-instance

*A way to start a Cassandra cluster with multiple instance per VM in Azure.*

Ideally, it is recommended to have small to medium-sized servers as Cassandra nodes rather than huge servers as Cassandra nodes.

Unfortunately, we might get something different from what we expect when we request a set of servers to build a database cluster like this one. The company probably already has established rules for the kind of hardware you'll get for a given role.

Having big servers for Cassandra is a waste of resources, unfortunately. The best way to work around this problem, and obtain the best from these big servers in terms of performance, assuming that [ScyllaDB](https://www.scylladb.com/) is not an option, is by having multiple instances of Cassandra running simultaneously on the same node. That's because, unlike ScyllaDB, Cassandra doesn't scale vertically, only horizontally.

Of course, this imposes some challenges when configuring the solution.

This recipe shows one way to solve this problem:

1) Have a dedicated directory for each instance to hold the configuration, data, and logs. This directory must point to a dedicated disk (or RAID0 set, but not RAID1 or RAID5) on the server (SSD is preferred).

2) As it is the IP address that Cassandra uses to identify itself as a node in the cluster, we need a dedicated NIC per instance so that each of them can have its own IP address.

3) Use a single `systemd` service definition to manage all the instances on a given server, offering a way to manipulate them individually when required.

4) Use Network Topology to enable rack-awareness so that each physical node can act as a rack from Cassandra's perspective, so replication would never happen in the same "rack" (or physical server). Otherwise, it is possible to lose data when a physical server goes down, as that means multiple Cassandra instances will go down simultaneously.

5) Based on the latest RPMs for Apache Cassandra, the only file that has to be modified from the installed files is `/usr/share/cassandra/cassandra.in.sh`, but that should not be a problem when upgrading the application.

6) Each instance within the same VM would have its own JMX port, as, unlike the client port, it binds to all the interfaces. For example, instance one listens on 7199, instance two on 7299, and so on.

We added a customized keyspace for OpenNMS/Newts designed for Multi-DC in mind (but for rack-awareness in our use case) using TWCS for the compaction strategy, the recommended configuration for production.

The latest version of OpenNMS Horizon will be started on a VM with PostgreSQL 12 on the same instance and all the necessary changes to monitor Cassandra with the multi-instance architecture in mind, which differs from the traditional method from a JMX perspective.

## Installation and usage

* Install the Azure CLI.

* Make sure to have your Azure credentials updated.

```bash
az login
```

* Install the Terraform binary from [terraform.io](https://www.terraform.io) (Version 0.13.x or newer required).

* Review [vars.tf](./vars.tf) if you want to alter something; alternatively override variables via the `terraform` command if necessary.

* Execute the following commands from the repository's root directory (at the same level as the `.tf` files):

```bash
terraform init
terraform apply -var "user=$USER"
```

It is expected you have your public SSH key available at `~/.ssh/id_rsa.pub`.

The above assumes there is already a resource group called `support-testing` created in Azure, on which Terraform will create all the resources.

If you want to create the resource group, you can run the following instead:

```bash
terraform apply \
  -var "user=$USER" \
  -var "resource_group_create=true" \
  -var "resource_group=OpenNMS" \
  -var "location=eastus"
```

* Each Cassandra instance is started one per rack at a time (as only one node can be joining a cluster at any given time) because the order is important. Before starting each instance, the script that controls the bootstrap process ensures that previous instances are ready for a smooth sequence minimizing the probability of initialization errors.

You could use `nodetool` to track joining progress and to make sure all the 9 instances have joined the cluster:

```bash
nodetool -u cassandra -pw cassandra status
```

If there are missing instances, log into the appropriate Cassandra server and check which instances are running:

```bash
systemctl status cassandra3@*
```

Let's say that the instance identified with `node2` is not running. Assuming that no other instance is joining the cluster, run the following:

```bash
systemctl start cassandra3@node2
```

Example of healthy status:

```bash
[agalue@agalue-cassandra1 ~]$ nodetool -u cassandra -pw cassandra status
Datacenter: Main
================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens  Owns (effective)  Host ID                               Rack
UN  14.0.1.30  69.88 KiB  16      18.1%             fef21f6b-1fd9-4dcc-94f1-00507a1f7f01  Rack3
UN  14.0.1.20  74.84 KiB  16      20.3%             05cbc8c2-c1bb-4ede-952f-ab2e5e4413be  Rack2
UN  14.0.1.10  97.31 KiB  16      25.5%             9a73e602-9418-4eee-979c-95ce200477ad  Rack1
UN  14.0.2.21  74.84 KiB  16      22.7%             37b29f7b-ae20-4cb5-8862-b92287cca939  Rack2
UN  14.0.2.11  69.87 KiB  16      26.2%             e32bc4cd-a867-4537-905c-5afae94bbafe  Rack1
UN  14.0.3.22  69.87 KiB  16      20.6%             0f8ae500-7ae3-45ef-9f9c-89c8ceed364c  Rack2
UN  14.0.3.32  69.87 KiB  16      20.7%             d1b09b8e-bb61-4d58-b09f-9e92f59e69e7  Rack3
UN  14.0.3.12  69.87 KiB  16      25.9%             6aaa99e1-56e5-403d-9d1f-e9ab32a52bc5  Rack1
UN  14.0.2.31  74.84 KiB  16      19.9%             be8a18d7-a9e5-420f-a403-3f0f14fbdae9  Rack3
```

* The OpenNMS instance will wait only for the seed node to be ready before starting, so we recommend waiting until the whole cluster is ready before monitoring the infrastructure.

* Import the requisition to collect JMX metrics from OpenNMS and the Cassandra servers every 30 seconds.

```bash
/opt/opennms/bin/provision.pl requisition import Infrastructure
```

* Connect to the Karaf Shell through SSH, ensuring the session won't die. Still, it is recommended to use `tmux` or `screen` if you're planning to leave the stress tool running constantly.

```bash
ssh -o ServerAliveInterval=10 -p 8101 admin@localhost
```

* Execute the `opennms:stress-metrics` command. The following is an example to generate 100000 samples per second:

```bash
opennms:stress-metrics -r 60 -n 15000 -f 20 -g 1 -a 100 -s 2 -t 100 -i 300
```

  We recommend a ring buffer of 2097152 and a cache size of about 600000 for the above command.

* Check the OpenNMS performance graphs to understand how it behaves. Additionally, you could check the Monitoring Tools on the Azure Console for each VM.

## Termination

To destroy all the resources, you should execute the `terraform destroy` command with the same variables you used when executed `terraform apply`, for instance:

```bash
terraform destroy -var "user=$USER"
```

Or,

```bash
terraform destroy \
  -var "user=$USER" \
  -var "resource_group_create=true" \
  -var "resource_group=OpenNMS"
```