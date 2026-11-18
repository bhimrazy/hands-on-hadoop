# Lab 06: File formats and small files

See why Parquet and ORC beat CSV, and why a pile of tiny files hurts HDFS.

| | |
|---|---|
| ⏱ Time | 30 minutes |
| 🧠 Docker memory | about 2.3 GB at peak |
| 🧩 Services | the core stack plus `notebook` (profile `notebook`) |
| Level | Intermediate |

Two choices shape how fast your data jobs are, before you write any query:

1. **File format.** CSV and JSON are *row* formats: to read one column you still read every row in full. Parquet and ORC are *columnar*: each column is stored together, compressed, and can be read on its own.
2. **File size.** HDFS likes a few big files, close to the 128 MB block size. The NameNode keeps an entry in memory for every file, directory and block, so thousands of tiny files waste its memory and make jobs start thousands of tiny tasks.

<img src="../../images/file-formats.svg" alt="Row formats store whole rows together, columnar formats store each column together" width="720">

You will measure both. This lab uses Spark in local mode, as in [lab 05](../05-spark-and-jupyter/README.md).

## Start

From the repo root:

```bash
docker compose --profile notebook up -d --wait
```

Check it is up: open <http://jupyter.localhost>. All `docker compose` commands in this lab run on your laptop.

## Steps

### 1. Open the first notebook

This lab has two notebooks. Copy both into your workspace so you can edit and save them.

```bash
docker compose exec notebook cp \
  /labs/06-file-formats-and-small-files/file-formats.ipynb \
  /labs/06-file-formats-and-small-files/small-files.ipynb /workspace/
```

Open `file-formats.ipynb` in JupyterLab and run the cells from the top (Shift+Enter). The steps below explain what each part does.

### 2. Write the same rows four ways

The notebook generates 500,000 rows (id, user, country, amount, a text comment, a timestamp) and writes them as CSV, JSON, Parquet and ORC under `/user/lab/06/formats/`.

Each copy uses two files, so the comparison is fair. The write takes a minute or so.

### 3. Compare sizes in HDFS

In a terminal:

```bash
docker compose exec namenode hdfs dfs -du -h /user/lab/06/formats
```

You should see numbers in this ballpark (yours will differ a little; the order will not):

```text
33.6 M  33.6 M  /user/lab/06/formats/csv
69.0 M  69.0 M  /user/lab/06/formats/json
 9.5 M   9.5 M  /user/lab/06/formats/orc
11.3 M  11.3 M  /user/lab/06/formats/parquet
```

The first column is the file size. The second is the space used by all replicas, which is the same here because replication is 1.

Why are Parquet and ORC so much smaller?

- Values of one column sit together, so they compress well (the `country` column repeats five words).
- Numbers are stored as numbers, not as text.
- JSON repeats every column name on every row.

### 4. Compare read speed for one column

The notebook computes `AVG(amount)` from each copy, three times each, and keeps the best time. It then draws two bar charts.

You should see a table shaped like this (seconds will differ on your laptop; the order should not):

```text
    format  seconds
0      csv      2.9
1     json      4.7
2  parquet      0.4
3      orc      0.5
```

CSV and JSON must read and parse every column. Parquet and ORC read only the `amount` column and skip the rest. That trick is called **column pruning**. Parquet and ORC also keep min/max values per chunk, which lets Spark skip chunks entirely when you filter.

### 5. Look at the file layout

Spark writes a folder, not a single file. Look inside one:

```bash
docker compose exec namenode hdfs dfs -ls -h /user/lab/06/formats/parquet
```

You should see:

```text
Found 3 items
-rw-r--r--   1 spark supergroup          0 ... /user/lab/06/formats/parquet/_SUCCESS
-rw-r--r--   1 spark supergroup        ... ... /user/lab/06/formats/parquet/part-00000-....snappy.parquet
-rw-r--r--   1 spark supergroup        ... ... /user/lab/06/formats/parquet/part-00001-....snappy.parquet
```

`_SUCCESS` is an empty marker that says "the write finished". Jobs that read this folder can wait for it.

### 6. The small files problem

The first notebook's last cell stopped its Spark session. Now open `small-files.ipynb` and run it from the top. It writes the same 5,000 rows twice:

- `/user/lab/06/small/many`: 500 files of about 10 rows each
- `/user/lab/06/small/one`: one file

Count them yourself:

```bash
docker compose exec namenode hdfs dfs -count /user/lab/06/small/many /user/lab/06/small/one
```

You should see (columns: directories, files, bytes, path):

```text
           1          501          ...   /user/lab/06/small/many
           1            2          ...   /user/lab/06/small/one
```

500 data files plus `_SUCCESS` is 501. Tiny files, but the NameNode tracks all of them, plus a block for each.

### 7. See it in the NameNode UI

Open <http://hdfs.localhost>. The Overview page has a line like this (your numbers will differ):

```text
2,600 files and directories, 1,500 blocks = 4,100 total filesystem object(s).
```

Every one of those objects lives in NameNode memory (rule of thumb: roughly 150 bytes each). A real cluster with hundreds of millions of tiny files runs out of NameNode memory long before it runs out of disk.

### 8. Compact

The fix for small files is to rewrite them as fewer, bigger ones. The last cells read the 500 files and write them back as one file with `coalesce(1)` into `/user/lab/06/small/compacted`.

```bash
docker compose exec namenode hdfs dfs -count /user/lab/06/small/compacted
```

You should see:

```text
           1            2          ...   /user/lab/06/small/compacted
```

`coalesce(1)` is fine for tiny data. For big data, pick a partition count so files end up near 128 MB each.

## Check yourself

```bash
docker compose exec namenode bash /labs/06-file-formats-and-small-files/check.sh
```

You should see:

```text
PASS  csv copy is in /user/lab/06/formats/csv
PASS  json copy is in /user/lab/06/formats/json
PASS  parquet copy is in /user/lab/06/formats/parquet
PASS  orc copy is in /user/lab/06/formats/orc
PASS  small/many holds 500 tiny files
PASS  small/one holds a single file
PASS  small/compacted holds a single file after compaction

All 7 checks passed
```

## Break it on purpose

**Make the problem four times worse.** The last cell of `small-files.ipynb` stopped Spark, so run its first code cell again. Then add a new cell at the bottom and run:

```python
spark.range(5000).repartition(2000).write.mode("overwrite").parquet("hdfs://namenode:8020/user/lab/06/small/way-too-many")
```

Watch it in the Spark UI (<http://spark.localhost>): 2,000 tasks for 5,000 rows, and it takes far longer than the 500-file write. Then reload <http://hdfs.localhost> and see the object count jump.

Delete it when you are done:

```bash
docker compose exec namenode hdfs dfs -rm -r /user/lab/06/small/way-too-many
```

## Going further

For 2 and 3, work in `file-formats.ipynb` with a running session: run its first code cell again.

1. Which compression codec does Spark use for Parquet by default?

   <details><summary>Solution</summary>

   Snappy: look at the file name (`part-....snappy.parquet`). Try zstd with `.option("compression", "zstd")` on the write and compare the size.

   </details>

2. Prove column pruning with `explain()`. Select one column from the Parquet copy and read the plan.

   <details><summary>Solution</summary>

   ```python
   spark.read.parquet(f"{BASE}/parquet").select("amount").explain()
   ```

   Look at `ReadSchema: struct<amount:double>`. Only one column is read.

   </details>

3. Try a filter. Does `WHERE amount > 499` read less data from Parquet than from CSV? Compare the "number of output rows" and "size of files read" in the Spark UI SQL tab.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Kernel dies while writing 500,000 rows | Memory. Close other notebooks (`spark.stop()`), or give Docker more memory ([docs/memory.md](../../docs/memory.md)). |
| `Cannot call methods on a stopped SparkContext` | The notebook's last cell stopped Spark. Run its first code cell again. |
| `PATH_ALREADY_EXISTS` error | You wrote without `mode("overwrite")`. Add it, or `hdfs dfs -rm -r` the folder. |
| Write of 500 files is slow | Expected on a laptop: each file costs a few HDFS round trips. It is the point of the demo. |

More in [docs/troubleshooting.md](../../docs/troubleshooting.md).

## Clean up

Lab 07 uses a different add-on, so stop this stack:

```bash
docker compose --profile "*" down
```

Your HDFS files stay. Lab 07 can query the Parquet copy you made here.

Next: [Lab 07, SQL with Hive](../07-sql-with-hive/README.md).
