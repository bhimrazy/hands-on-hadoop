# Lab 08: Iceberg tables

Get UPDATE, DELETE, MERGE, snapshots and time travel on plain HDFS files with Apache Iceberg.

| | |
|---|---|
| ⏱ Time | 30 minutes |
| 🧠 Docker memory | about 2.3 GB peak (core + notebook) |
| 🧩 Services | namenode, datanode, resourcemanager, nodemanager, proxy, **notebook** |
| Level | Advanced |

<img src="../../images/iceberg-snapshots.svg" alt="An Iceberg table: a metadata file points to a snapshot, which lists manifests, which list Parquet data files" width="720">

## The big idea

HDFS files are write-once. You cannot change row 3 of a Parquet file. So how can a table support `UPDATE`?

**Iceberg is a table format.** It does not store data itself. It adds a small tree of metadata files next to your Parquet files:

1. A **metadata file** (`v3.metadata.json`) lists the table's schema and all its snapshots.
2. Each **snapshot** is one version of the table. It points to a manifest list.
3. **Manifests** list the data files that belong to that version.
4. **Data files** are ordinary Parquet.

An `UPDATE` writes new data files and a new snapshot. The old snapshot still points at the old files, so you can read the table as it was before. That is **time travel**.

You will use a **Hadoop catalog**: the catalog is simply a folder in HDFS (`/user/lab/08/warehouse`). No Hive metastore or database is needed. Good for learning. Real clusters usually use a Hive, REST or cloud catalog, because with a plain Hadoop catalog two writers at once can clash.

Spark runs in local mode in the notebook container, as in [lab 05](../05-spark-and-jupyter/README.md). The Iceberg runtime jar is already on its classpath.

## Start

```bash
docker compose --profile notebook up -d --wait
```

Check it's up: open <http://jupyter.localhost>.

## Steps

### 1. Open the notebook

```bash
docker compose exec notebook cp /labs/08-iceberg-tables/iceberg-orders.ipynb /workspace/
```

Open `iceberg-orders.ipynb` in JupyterLab. Make sure no other notebook still has a Spark session running (use *Kernel > Shut Down All Kernels*), because two Spark sessions in 1.5 GB of memory is tight.

### 2. Configure the catalog

The first cell sets up Spark and names the catalog `lab`:

```python
.config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
.config("spark.sql.catalog.lab", "org.apache.iceberg.spark.SparkCatalog")
.config("spark.sql.catalog.lab.type", "hadoop")
.config("spark.sql.catalog.lab.warehouse", "hdfs://namenode:8020/user/lab/08/warehouse")
```

- The *extensions* line turns on `UPDATE`, `DELETE` and `MERGE` for Iceberg tables.
- `lab` is the catalog name. Tables are now written `lab.<namespace>.<table>`.
- `type=hadoop` means "keep the catalog in the warehouse folder".

### 3. Create a table and insert rows

```sql
CREATE TABLE lab.shop.orders (
  order_id BIGINT, customer STRING, item STRING,
  qty INT, price DECIMAL(8, 2), status STRING
) USING iceberg
```

Then `INSERT` five rows. You should see them listed:

```text
+--------+--------+--------+---+-----+---------+
|order_id|customer|    item|qty|price|   status|
+--------+--------+--------+---+-----+---------+
|       1|    asha|notebook|  2| 3.50|      new|
...
```

### 4. Update, delete and merge

The notebook then runs:

- `UPDATE ... SET status = 'shipped' WHERE order_id IN (1, 2)`
- `DELETE FROM ... WHERE status = 'cancelled'`
- `MERGE INTO ... USING incoming` (an upsert: order 3 changes, order 6 is new)

Each statement creates a new snapshot. None of them edits an HDFS file in place.

### 5. List the snapshots

```text
+-------------------+-----------------------+---------+-----+-------+
|snapshot_id        |committed_at           |operation|added|deleted|
+-------------------+-----------------------+---------+-----+-------+
|8189...            |2026-11-18 10:02:11.4  |append   |5    |NULL   |
|3301...            |2026-11-18 10:02:14.9  |overwrite|2    |2      |
|6740...            |2026-11-18 10:02:16.1  |overwrite|NULL |1      |
|5512...            |2026-11-18 10:02:19.7  |overwrite|2    |1      |
+-------------------+-----------------------+---------+-----+-------+
```

The IDs and times will be different. What matters: **one row per change**, and the `operation` column tells you what kind. (`snapshots` is a *metadata table*: `lab.shop.orders.snapshots`. Others you can try: `.history`, `.files`, `.manifests`.)

### 6. Time travel

Two ways to go back:

```sql
SELECT * FROM lab.shop.orders VERSION AS OF 8189...;            -- by snapshot id
SELECT * FROM lab.shop.orders TIMESTAMP AS OF '2026-11-18 10:02:14.900';  -- by time
```

The first one shows the original five rows, including the cancelled order. The current table no longer has it.

The notebook fills in the real ID and time for you.

### 7. Evolve the schema

```sql
ALTER TABLE lab.shop.orders ADD COLUMN coupon STRING;
ALTER TABLE lab.shop.orders RENAME COLUMN qty TO quantity;
```

Old rows show `NULL` in `coupon`. No data file was rewritten, only metadata changed. Compare that with a plain Hive table, where renaming a column often means rewriting the files.

### 8. See the files in HDFS

The last cells list the table folder. You can also use the NameNode terminal:

```bash
docker compose exec namenode hdfs dfs -ls -R /user/lab/08/warehouse/shop/orders
```

You should see (trimmed):

```text
.../orders/data/00000-3-....parquet
.../orders/data/00000-12-....parquet
.../orders/metadata/v1.metadata.json ... v9.metadata.json
.../orders/metadata/snap-8189...-1-....avro
.../orders/metadata/....-m0.avro
.../orders/metadata/version-hint.text
```

Match them to the picture:

- `*.metadata.json`: one per table change. Open the newest: `hdfs dfs -cat .../metadata/*.metadata.json | jq .` is long, but you can find the `schemas` and `snapshots` lists.
- `snap-*.avro`: a manifest list, one per snapshot.
- `*-m0.avro`: a manifest, listing data files with row counts and min/max values.
- `data/*.parquet`: the rows.
- `version-hint.text`: a tiny file that says which `metadata.json` is current.

Many data files from earlier snapshots are still there. They belong to old snapshots you can still travel to.

## Check yourself

```bash
docker compose exec namenode bash /labs/08-iceberg-tables/check.sh
```

You should see:

```text
PASS  the table has a version-hint.text
PASS  metadata/ holds 9 vN.metadata.json files (one per table change)
PASS  data/ holds Parquet files
PASS  the schema in metadata includes the coupon column (schema evolution)
All 4 checks passed
```

## Break it on purpose

Delete the metadata and see what is left. Make a throw-away table first, so your lab table stays safe. In a new notebook cell:

```python
spark.sql("CREATE TABLE lab.shop.scratch (id INT) USING iceberg")
spark.sql("INSERT INTO lab.shop.scratch VALUES (1), (2)")
```

Then in a terminal, remove only the metadata folder:

```bash
docker compose exec namenode hdfs dfs -rm -r -skipTrash /user/lab/08/warehouse/shop/scratch/metadata
```

Back in the notebook:

```python
spark.sql("SELECT * FROM lab.shop.scratch").show()
```

You get a `NoSuchTableException`. The Parquet files in `data/` are still in HDFS, but without metadata nothing knows they form a table. The metadata *is* the table.

## Going further

1. Expire old snapshots to free space. What happens to time travel?
   <details><summary>Solution</summary>

   ```python
   spark.sql("""
     CALL lab.system.expire_snapshots(table => 'shop.orders',
       older_than => TIMESTAMP '2999-01-01 00:00:00', retain_last => 1)
   """).show()
   ```
   Only the newest snapshot is kept and the unreachable data files are deleted. `VERSION AS OF <old id>` now fails.
   </details>
2. Compact small files, like lab 06, but with Iceberg's own procedure.
   <details><summary>Solution</summary>

   ```python
   spark.sql("CALL lab.system.rewrite_data_files(table => 'shop.orders')").show()
   ```
   A new snapshot with `operation = replace` appears.
   </details>
3. Roll the table back to its first snapshot.
   <details><summary>Solution</summary>

   ```python
   first = spark.sql("SELECT snapshot_id FROM lab.shop.orders.snapshots ORDER BY committed_at").first()[0]
   spark.sql(f"CALL lab.system.rollback_to_snapshot('shop.orders', {first})")
   ```
   </details>

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ClassNotFoundException: org.apache.iceberg.spark.SparkCatalog` | The Iceberg jar is missing from the notebook image. Rebuild it: `docker compose build notebook`. |
| `UPDATE` or `MERGE` fails with "not supported" | The `spark.sql.extensions` line was lost. Restart the kernel and run the first cell again. |
| `Table already exists` after a half-finished run | Run the first cells again. The notebook drops and recreates `lab.shop.orders` with `PURGE`. |
| Kernel dies (`Killed`) | Memory. Shut down other kernels (*Kernel > Shut Down All Kernels*) and run again. |

More in [docs/troubleshooting.md](../../docs/troubleshooting.md).

## Clean up

```bash
docker compose --profile "*" down
```

Next: [Lab 09: Kafka streaming](../09-kafka-streaming/README.md).
