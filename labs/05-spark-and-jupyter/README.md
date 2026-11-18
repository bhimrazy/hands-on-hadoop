# Lab 05: Spark and Jupyter

Count words with Spark in a notebook, read and write HDFS, and see how it compares with the MapReduce job from lab 02.

| | |
|---|---|
| ⏱ Time | 25 minutes |
| 🧠 Docker memory | about 2.3 GB at peak |
| 🧩 Services | the core stack plus `notebook` (profile `notebook`) |
| Level | Intermediate |

In lab 02 you wrote a mapper and a reducer by hand. Spark says the same thing in a few lines: split lines into words, group by word, count. It also keeps data in memory between steps, so it is usually much faster than MapReduce.

<img src="../../images/spark-on-hdfs.svg" alt="A Spark driver in the notebook container reading and writing files in HDFS" width="720">

**Spark runs in local mode here.** The whole Spark program runs as threads inside the `notebook` container. It does not use YARN, because the Hadoop image runs Java 11 and Spark 4 needs Java 17 or newer. Spark still reads and writes the same HDFS over the network.

On a real cluster you would start Spark with `--master yarn`, and YARN would give it containers on many machines, as it did for MapReduce in lab 02. The DataFrame code stays the same.

## Start

From the repo root:

```bash
docker compose --profile notebook up -d --wait
```

The first start builds the notebook image, which takes a few minutes. The command returns when every container is `Healthy`.

Check it is up: open <http://jupyter.localhost>. You should see JupyterLab. All `docker compose` commands in this lab run on your laptop.

## Steps

### 1. Copy the notebook into your workspace

JupyterLab shows the repo's `workspace/` folder. The lab files are mounted read-only at `/labs`, so copy the notebook into the workspace, where you can edit and save it.

```bash
docker compose exec notebook cp /labs/05-spark-and-jupyter/word-count-with-spark.ipynb /workspace/
```

In JupyterLab, double-click `word-count-with-spark.ipynb` in the file browser on the left.

### 2. Start a SparkSession

A `SparkSession` is your connection to Spark. Run the first code cell (click it, then press Shift+Enter). The main lines are:

```python
spark = (
    SparkSession.builder
    .master("local[*]")
    .appName("lab-05-spark-and-jupyter")
    ...
    .getOrCreate()
)
```

`local[*]` means "use every CPU core of this container". The app name is what you will see in the Spark UI.

You should see:

```text
Spark 4.1.3
Spark UI: http://spark.localhost
```

### 3. Put some input into HDFS

Run the next cell. It makes 20,000 lines of random words and writes them to `hdfs://namenode:8020/user/lab/05/input` with Spark itself, so there is nothing to download.

Look at it from the HDFS side in a terminal:

```bash
docker compose exec namenode hdfs dfs -ls /user/lab/05/input
```

You should see:

```text
Found 3 items
-rw-r--r--   1 spark supergroup          0 ... /user/lab/05/input/_SUCCESS
-rw-r--r--   1 spark supergroup        ... ... /user/lab/05/input/part-00000-....txt
-rw-r--r--   1 spark supergroup        ... ... /user/lab/05/input/part-00001-....txt
```

Two part files, because the cell asked for two partitions with `repartition(2)`.

### 4. Count the words

Run the next cell. It reads the text back from HDFS and counts the words:

```python
words = text.select(F.explode(F.split(F.lower("value"), r"\s+")).alias("word")).filter("word <> ''")
counts = words.groupBy("word").count().orderBy(F.desc("count"))
counts.show(10)
```

`explode` makes one row per word. `groupBy("word").count()` is the map and reduce in one line.

You should see the first three lines of the input, then a table that starts like this (the counts are around these values):

```text
+------+-----+
|  word|count|
+------+-----+
|  data|53513|
|hadoop|26591|
|  hdfs|17653|
...
```

### 5. Read the plan with `explain()`

Spark is lazy. Nothing runs until you ask for a result (`show`, `count`, `write`). The next cell calls `explain()`, which prints the plan Spark built (trimmed):

```text
== Physical Plan ==
AdaptiveSparkPlan isFinalPlan=false
+- Sort [count#.. DESC NULLS LAST], true, 0
   +- Exchange rangepartitioning(count#.. DESC NULLS LAST, 4)
      +- HashAggregate(keys=[word#..], functions=[count(1)])
         +- Exchange hashpartitioning(word#.., 4)
            +- HashAggregate(keys=[word#..], functions=[partial_count(1)])
               +- ... FileScan text [value#..] ... hdfs://namenode:8020/user/lab/05/input
```

Your plan has a few more lines.

Read it from the bottom up:

- `FileScan` reads the text from HDFS.
- The first `HashAggregate` counts words inside each partition (like a combiner).
- `Exchange hashpartitioning` is the **shuffle**: the same word goes to the same partition (like MapReduce shuffle).
- The second `HashAggregate` adds up the partial counts.

### 6. Open the Spark UI

The Spark UI shows what the plan did when it ran. While your notebook session is running, open <http://spark.localhost>.

- **Jobs** lists the jobs each action (`show`, `write`...) started. Click one to see its stages.
- **SQL / DataFrame** shows the plan as a picture, with row counts on each arrow.
- **Environment** shows `spark.master = local[*]`.

The UI disappears when the session stops (last cell of the notebook). That is normal.

### 7. Chart it

`toPandas()` brings the top 10 rows into the notebook as a pandas DataFrame, and seaborn draws a bar chart. This is the usual pattern: let Spark crunch big data, then plot the small result.

> Never `toPandas()` a big table. It pulls everything into one process.

### 8. Write Parquet to HDFS

The next cell writes the full word counts as Parquet and a top-10 list as one small CSV. Run it, then look at both from a terminal:

```bash
docker compose exec namenode hdfs dfs -ls /user/lab/05/word-counts-parquet
docker compose exec namenode hdfs dfs -cat /user/lab/05/top-words/*.csv
```

You should see the Parquet folder with a `_SUCCESS` marker and one or more `part-....snappy.parquet` files, then the CSV:

```text
word,count
data,53513
hadoop,26591
...
```

Lab 06 explains why Parquet is a good default. The last cell, `spark.stop()`, ends the session and frees its memory.

## Check yourself

```bash
docker compose exec namenode bash /labs/05-spark-and-jupyter/check.sh
```

You should see:

```text
PASS  input text is in /user/lab/05/input
PASS  word counts were written as Parquet
PASS  Parquet data files exist in /user/lab/05/word-counts-parquet
PASS  top-words CSV lists 'data' as a top word

All 4 checks passed
```

## Break it on purpose

The last cell stopped Spark, so run the first code cell again to get a session back. Then add a new cell at the bottom for each experiment.

**Read a folder that does not exist.**

```python
spark.read.text("hdfs://namenode:8020/user/lab/05/nope").show()
```

You should see an `AnalysisException: [PATH_NOT_FOUND] Path does not exist`. Spark checks the path when it builds the plan, before any job starts, so the Spark UI shows no new job.

**Use a wrong NameNode address.**

```python
spark.read.text("hdfs://nonamenode:8020/user/lab/05/input").show()
```

This one fails with an `UnknownHostException`. A path error means HDFS answered. A host or connection error means Spark never reached it.

## Going further

These need a running session and the `text` and `counts` variables, so run the notebook's cells again first, except the last one.

1. Read the lab 02 result with Spark. If you still have `/lab02/out-java`, it is tab separated: word, count.

   <details><summary>Solution</summary>

   ```python
   spark.read.csv("hdfs://namenode:8020/lab02/out-java", sep="\t", schema="word STRING, count INT").show()
   ```

   </details>

2. Shrink the shuffle. Set `spark.sql.shuffle.partitions` to 1, re-run the count and compare the stages in the Spark UI.

   <details><summary>Solution</summary>

   ```python
   spark.conf.set("spark.sql.shuffle.partitions", "1")
   counts.collect()
   ```

   Fewer shuffle partitions means fewer tasks in the stage after the shuffle.

   </details>

3. Count lines by their number of words. Group by `size(split(value, ' '))` instead of by word.

   <details><summary>Solution</summary>

   ```python
   text.groupBy(F.size(F.split("value", " ")).alias("words_in_line")).count().orderBy("words_in_line").show()
   ```

   </details>

## Troubleshooting

| Symptom | Fix |
|---|---|
| <http://spark.localhost> returns a 502 error | The Spark UI only exists while a SparkSession is running. Run the first code cell again. |
| `Cannot call methods on a stopped SparkContext` | The last cell stopped Spark. Run the first code cell again. |
| `Address already in use` for port 4040 warning, UI on 4041 | Another kernel still has a session open. Run `spark.stop()` there, or restart that kernel. |
| `Connection refused` to `namenode:8020` | HDFS is still starting. Wait a few seconds and check `docker compose ps`. |
| Kernel dies (`Killed`) | The notebook container ran out of memory. Close other notebooks and stop unused services. See [docs/memory.md](../../docs/memory.md). |

More in [docs/troubleshooting.md](../../docs/troubleshooting.md).

## Clean up

Stop Spark first (the last cell does this). Then leave the stack running for the next lab, which uses the same services, or stop it:

```bash
docker compose --profile "*" down
```

Your HDFS files and your copy of the notebook in `workspace/` stay.

Next: [Lab 06, File formats and small files](../06-file-formats-and-small-files/README.md).
