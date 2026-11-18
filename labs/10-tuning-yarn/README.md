# Lab 10: Tuning YARN

Read how much room your NodeManager has, work out how many tasks fit, make a job wait on purpose, then change the cluster's settings and see what moves.

| | |
|---|---|
| ⏱ Time | 45 minutes |
| 🧠 Docker memory | about 2.2 GB at peak |
| 🧩 Services | the core stack (`namenode`, `datanode`, `resourcemanager`, `nodemanager`, `proxy`) |
| Level | Advanced |

YARN hands out memory in **containers**. A job asks for some, and the **ResourceManager** says yes only if the **NodeManager** has room. When it doesn't, the job waits. That wait is what you'll see here.

<img src="../../images/yarn-memory.svg" alt="The NodeManager's 768 MB split into a 384 MB ApplicationMaster container, one 256 MB map container and 128 MB left over" width="720">

## Start

Stop anything left over from another lab, then start the core stack. From the repo root:

```bash
docker compose --profile "*" down
docker compose up -d --wait
```

Check it is up: open <http://yarn.localhost>. The **Active Nodes** count should be `1`.

Open a shell in the `namenode` container. Steps 1 to 5 run there.

```bash
docker compose exec namenode bash
```

## Steps

### 1. Read the cluster's capacity

Before you tune anything, find out how much there is to hand out. Open <http://yarn.localhost> and look at the cluster metrics at the top and at **Nodes** in the left menu. Or ask the ResourceManager's REST API from the shell:

```bash
curl -s http://yarn.localhost/ws/v1/cluster/metrics | jq '.clusterMetrics | {totalMB, totalVirtualCores, availableMB}'
```

You should see:

```json
{
  "totalMB": 768,
  "totalVirtualCores": 2,
  "availableMB": 768
}
```

This comes from `yarn.nodemanager.resource.memory-mb` (768) and `cpu-vcores` (2) in [compose.yaml](../../compose.yaml). The NodeManager container has a 1 GB limit; 768 MB of it is lent to jobs and the rest is the NodeManager's own JVM.

Two more limits matter:

| Setting | Value | Meaning |
|---|---|---|
| `yarn.scheduler.minimum-allocation-mb` | 128 | Every request is rounded up to a multiple of this. |
| `yarn.scheduler.maximum-allocation-mb` | 768 | One container may not be bigger than this. |

### 2. Do the sums

A wordcount job needs one **ApplicationMaster** (AM, the job's coordinator) at 384 MB, plus map containers at 256 MB each.

```text
768 MB total
- 384 MB ApplicationMaster
= 384 MB left
384 / 256 = 1.5  ->  1 map container at a time (128 MB unused)
```

So this cluster runs **one map at a time**, however many map tasks the job has. The other tasks queue. (YARN here counts memory only; the 2 vcores are shown but not enforced.)

### 3. Run a job with many maps

Wordcount makes one map task per input file. Make six small files:

```bash
hdfs dfs -mkdir -p /user/lab/10/input
for i in 1 2 3 4 5 6; do
  echo "hadoop yarn container $i hadoop memory" | hdfs dfs -put - /user/lab/10/input/file-$i.txt
done
```

Start the job and leave it running:

```bash
hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar \
  wordcount /user/lab/10/input /user/lab/10/out-baseline
```

Open a **second namenode shell** (`docker compose exec namenode bash` in a new terminal) and watch YARN while the job runs:

```bash
for i in $(seq 1 10); do
  curl -s http://yarn.localhost/ws/v1/cluster/metrics | jq -c '.clusterMetrics | {allocatedMB, availableMB, containersAllocated, containersPending}'
  sleep 5
done
```

You should see something like:

```text
{"allocatedMB":384,"availableMB":384,"containersAllocated":1,"containersPending":0}
{"allocatedMB":640,"availableMB":128,"containersAllocated":2,"containersPending":5}
{"allocatedMB":640,"availableMB":128,"containersAllocated":2,"containersPending":4}
```

Two containers (AM and one map) use 640 MB. 128 MB is free, which is too small for another 256 MB map, so five wait in `containersPending`. Also look at the **Applications** page: the job has one running attempt, and as each map finishes the next one starts. The first job takes a minute or two.

### 4. Break it on purpose: ask for too much

This lab breaks things in the middle, because the error explains the limits from step 1. Ask for an ApplicationMaster bigger than the biggest container YARN allows:

```bash
hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar \
  wordcount -Dyarn.app.mapreduce.am.resource.mb=1024 \
  /user/lab/10/input /user/lab/10/out-toobig
```

You should see the job refused straight away:

```text
org.apache.hadoop.yarn.exceptions.InvalidResourceRequestException:
Invalid resource request! Cannot allocate containers as requested resource is greater than
maximum allowed allocation. Requested resource type=[memory-mb], Requested resource=<memory:1024, vCores:1>,
maximum allowed allocation=<memory:768, vCores:2>, please note that maximum allowed allocation is
calculated by scheduler based on maximum resource of registered NodeManagers ...
```

Read it left to right: what you asked for (1024 MB) and the ceiling (768 MB). Nothing is wrong with the cluster. The request can never fit, so YARN refuses it at once instead of letting it wait forever. A map or reduce request that is too big (`-Dmapreduce.map.memory.mb=1024`) gets the same message, but in the ApplicationMaster's log instead of your terminal.

### 5. Tune the job, not the cluster

You can shrink a job's containers with `-D` options, with no restart. Smaller maps (and a smaller heap inside each) mean more of them fit:

```bash
hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar \
  wordcount \
  -Dmapreduce.map.memory.mb=128 -Dmapreduce.map.java.opts=-Xmx100m \
  -Dmapreduce.reduce.memory.mb=128 -Dmapreduce.reduce.java.opts=-Xmx100m \
  -Dmapreduce.task.io.sort.mb=32 \
  /user/lab/10/input /user/lab/10/out-tuned
```

`io.sort.mb` shrinks each map's sort buffer from its 100 MB default. Without it the buffer alone fills the 100 MB heap and every map fails with `Java heap space`.

Run the metrics loop from step 3 again in the second terminal. Now `(768 - 384) / 128 = 3` maps run side by side:

```text
{"allocatedMB":768,"availableMB":0,"containersAllocated":4,"containersPending":3}
```

Compare **Elapsed** for both jobs on the Applications page now. Step 6 restarts the ResourceManager, which clears that list. The tuned job should finish sooner, but the AM start-up time is the same, so the win is smaller than you might expect. Make containers too small and tasks run out of heap (`OutOfMemoryError`, or exit code 143 or 137). You can only trade memory for parallelism down to what a task needs.

### 6. Tune the cluster with a compose override

Some settings belong to the ResourceManager, so the job can't change them. Here we add a second **queue**. Queues split the cluster between groups of users or kinds of work: `default` (interactive) and `batch` (long jobs).

The file [compose.override-example.yaml](compose.override-example.yaml) sets the queues as environment variables on the `resourcemanager`. Type `exit` to leave the namenode shell: the rest of this step runs on your laptop. Apply the override by naming both files, and recreate only the ResourceManager:

```bash
docker compose -f compose.yaml -f labs/10-tuning-yarn/compose.override-example.yaml \
  up -d --no-deps --force-recreate resourcemanager
```

The NodeManager notices and registers again. Wait until it is back:

```bash
docker compose exec namenode bash -c "curl -s http://yarn.localhost/ws/v1/cluster/metrics | jq '.clusterMetrics.activeNodes'"
```

You should see `1` after 10 to 30 seconds (it can be `0` for a moment). Now look at the queues:

```bash
docker compose exec namenode yarn queue -status batch
```

You should see (trimmed):

```text
Queue Name : batch
	State : RUNNING
	Capacity : 50.0%
	Maximum Capacity : 100.0%
```

Open **Scheduler** in the YARN UI: two bars, `default` and `batch`, each guaranteed half of the 768 MB but allowed to borrow up to all of it while the other is idle.

Compose only applies the override when you name it with `-f`. A plain `docker compose up` uses `compose.yaml` alone.

### 7. Submit to a queue

Open the namenode shell again (`docker compose exec namenode bash`) and send a job to the new queue with `mapreduce.job.queuename`:

```bash
hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar \
  wordcount -Dmapreduce.job.queuename=batch \
  /user/lab/10/input /user/lab/10/out-queue
```

On the Applications page, the **Queue** column says `batch`. While the job runs, the Scheduler page shows the `batch` bar filling up.

## Check yourself

Run the check while the override is still applied. In the namenode shell:

```bash
bash /labs/10-tuning-yarn/check.sh
```

You should see:

```text
PASS  Baseline job finished (out-baseline)
PASS  Baseline wordcount output
PASS  Tuned job finished (out-tuned)
PASS  Job in the batch queue finished (out-queue)
PASS  Scheduler has a queue named batch
PASS  A finished application ran in queue batch

All 6 checks passed
```

## Break it on purpose

Step 4 is this lab's break: a request above `yarn.scheduler.maximum-allocation-mb` is refused at once.

## Going further

1. Start two wordcounts at once, from two namenode shells, with different output folders. One sits in `ACCEPTED`. Why?

   <details><summary>Solution</summary>

   A job only goes to `RUNNING` when its ApplicationMaster has a container. The scheduler limits how much of a queue ApplicationMasters may hold (`yarn.scheduler.capacity.maximum-am-resource-percent`, 10 percent by default) and always lets at least the first one in. So the second job waits until the first finishes. That is a good thing here: two 384 MB ApplicationMasters would fill the 768 MB and leave no room for any map. Other causes of `ACCEPTED`: not enough free memory for the AM, or a queue at its maximum capacity.

   </details>

2. Add `YARN-SITE.XML_yarn.scheduler.minimum-allocation-mb: "256"` to the override, recreate the ResourceManager, and run the tuned job (128 MB maps) into a new output folder. What memory does each container get?

   <details><summary>Solution</summary>

   256 MB, because requests are rounded up to a multiple of the minimum. The three-at-a-time speed-up from step 5 goes away. `allocatedMB` in the metrics loop shows it.

   </details>

3. Run wordcount with `-Dmapreduce.job.reduces=2`. Does the output change?

   <details><summary>Solution</summary>

   You get `part-r-00000` and `part-r-00001`, each holding some of the words. Total counts are the same. On a one-node cluster extra reducers add start-up cost and no speed.

   </details>

## Troubleshooting

| Symptom | Fix |
|---|---|
| `curl: Could not resolve host: yarn.localhost` | Run it inside the namenode shell, or open the URL in your browser. |
| `docker: command not found` | You are inside the namenode shell. Type `exit` first. |
| After step 6 `activeNodes` stays `0` | Wait a minute. If still 0, `docker compose restart nodemanager`. |
| A job in the `batch` queue stays in `ACCEPTED` or its maps never start | The override must include the `user-limit-factor` lines; with the default of 1 a user can't use more than the queue's own half. |
| `Queue 'batch' does not exist` | The override wasn't applied. Check you passed both `-f` files and recreated `resourcemanager`. |
| Output directory already exists | `hdfs dfs -rm -r /user/lab/10/out-baseline` (or the one you reused). |

More in [docs/troubleshooting.md](../../docs/troubleshooting.md).

## Clean up

Type `exit` to leave the namenode shell, then:

```bash
docker compose --profile "*" down
```

Your HDFS files stay. Add `-v` to wipe them. The next `docker compose up -d --wait` starts the ResourceManager without the override, so the `batch` queue is gone.

You've finished the labs. Go back to the [learning path](../../README.md), or look at [how this maps to a manual VM install](../../docs/vm-install-comparison.md).
