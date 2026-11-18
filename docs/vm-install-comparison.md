# Compared with a manual VM install

Hadoop guides usually have you install it by hand on an Ubuntu VM, with every daemon on one machine at `localhost`. This repo runs the same daemons, one per container, and each container is its own host (`namenode`, `resourcemanager`, and so on). That is why the config says `namenode:8020` where a guide says `localhost:9000`.

| # | Manual VM step | Here |
|---|---|---|
| 1 | Create an Ubuntu VM, `apt update` | Docker runs the containers. |
| 2 | Install Java, set `JAVA_HOME` | Built into the image (OpenJDK 11). |
| 3 | Create a `hadoop` user | The image already runs as the `hadoop` user. |
| 4 | Download the tarball, set `HADOOP_HOME` and `PATH` | Built into the image at `/opt/hadoop`, already on `PATH`. |
| 5 | Edit `core-site.xml`, `hdfs-site.xml`, `yarn-site.xml`, `mapred-site.xml` | Environment variables in [compose.yaml](../compose.yaml), turned into XML at startup. |
| 6 | Create and `chown` the NameNode and DataNode folders | Docker volumes at `/data` in `namenode` and `datanode`. |
| 7 | Set up passwordless SSH keys | Not needed. See below. |
| 8 | `hdfs namenode -format` | Automatic on first start. |
| 9 | `start-dfs.sh`, `start-yarn.sh` | `docker compose up -d --wait` |
| 10 | `jps` | `docker compose ps` shows the services; `jps` runs per container (below). |
| 11 | Open `localhost:9870` and `localhost:8088` | Open <http://hdfs.localhost> and <http://yarn.localhost>. |

## Why the guide needs passwordless SSH

In a real cluster, Hadoop runs on many machines: one master and many workers. You start the whole cluster from the master. `start-dfs.sh` reads the worker hostnames from `etc/hadoop/workers` and SSHes into each one to start its daemon. Key-based SSH lets it do that without asking for a password on every machine.

```text
master                          workers
+---------------------+  ssh   +-----------------------+
| start-dfs.sh        | -----> | worker1: DataNode,    |
| start-yarn.sh       |        |          NodeManager  |
| NameNode            |  RPC   +-----------------------+
| ResourceManager     | <----> | worker2: DataNode,    |
+---------------------+        |          NodeManager  |
                               +-----------------------+
```

- **SSH only starts and stops daemons.** Once they run, they talk over Hadoop's own RPC ports, such as 8020 for the NameNode (heartbeats, block reports, job status). SSH plays no part in storage or jobs.
- **A single-node VM keeps the same scripts.** Its worker list is just `localhost`, so it SSHes into itself. That's why a one-machine guide still sets up SSH.
- **This repo needs no SSH.** Docker starts each daemon in its own container, so Docker takes the place of the start scripts.
- **Production clusters** usually manage daemons with tools like Ambari, Cloudera Manager or Kubernetes rather than the SSH scripts. The idea is the same: one control point starts daemons on every node.

## Running `jps`

`jps` lists the Java processes on one machine, and here each container is a machine. To see all four Hadoop daemons at once:

```bash
for s in namenode datanode resourcemanager nodemanager; do
  echo "== $s"
  docker compose exec $s jps | grep -v Jps
done
```

You should see one daemon per container:

```text
== namenode
1 NameNode
== datanode
1 DataNode
== resourcemanager
1 ResourceManager
== nodemanager
1 NodeManager
```

(The process IDs will differ.) While a job runs, the `nodemanager` also lists short-lived `YarnChild` and `MRAppMaster` processes: those are your tasks.

## Config

Each variable in [compose.yaml](../compose.yaml) has a comment. To see the XML the image generates from them:

```bash
docker compose exec namenode cat /opt/hadoop/etc/hadoop/core-site.xml
```

The rule: `FILE.XML_property.name: value` becomes a `<property>` in `FILE.xml`. That is how lab 10 adds queues with `CAPACITY-SCHEDULER.XML_...`.

<details>
<summary>Config values: guide vs this repo</summary>

| File | Property | Guide | Here | Why |
|---|---|---|---|---|
| core | `fs.defaultFS` | `hdfs://localhost:9000` | `hdfs://namenode:8020` | NameNode is its own container; 8020 is the default port. |
| core | `hadoop.tmp.dir` | `/usr/local/hadoop/tmp` | default | Storage folders are set explicitly instead. |
| hdfs | `dfs.replication` | `1` | `1` (`2` in lab 04) | One DataNode in the core. |
| hdfs | `dfs.namenode.name.dir`, `dfs.datanode.data.dir` | under `/usr/local/hadoop/hdfs` | `/data/namenode`, `/data/datanode` | On Docker volumes, so data is kept between runs. |
| hdfs | `dfs.permissions.enabled` | `false` | `false` | No `chown` needed to write. |
| hdfs | `dfs.datanode.hostname` | not set | `localhost` | Lets the HDFS UI's download links work from your computer. |
| hdfs | `dfs.namenode.safemode.extension` | 30 s | 5 s | Short safe mode after a restart. |
| mapred | `mapreduce.framework.name` | `yarn` | `yarn` | Jobs run on YARN. |
| mapred | map/reduce memory | `512` MB, `-Xmx410m` | `256` MB, `-Xmx200m` | Fits YARN's 768 MB. |
| mapred | ApplicationMaster memory | default (1536 MB) | `384` MB, `-Xmx288m` | The default wouldn't fit. |
| mapred | `jobhistory.*` | `localhost:10020`, `:19888` | set by the `history` profile | No History Server in the core, to save memory. |
| yarn | `yarn.resourcemanager.hostname` | `localhost` (plus each address) | `resourcemanager` | All RM addresses follow from the hostname. |
| yarn | `aux-services` | `mapreduce_shuffle` | `mapreduce_shuffle` | Needed for MapReduce. |
| yarn | NodeManager memory / cores | `1024` MB / `1` | `768` MB / `2` | Fits the 1 GB container limit. |
| yarn | `vmem-check-enabled` | `false` | `false` | Stops YARN killing JVMs over virtual memory. |
| yarn | `pmem-check-enabled` | `false` | default (`true`) | YARN kills a task that goes over its allocation before the container limit is reached. |
| yarn | heartbeat, timeouts, local and log dirs | set | defaults | Not needed for short lab jobs. |

</details>
