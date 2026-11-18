# Troubleshooting

Find your symptom, try the fix. If nothing here helps, run `docker compose logs <service>` (for example `docker compose logs namenode`) and read the last 30 lines. Most problems are one of: not enough memory, a service that is still starting, or an old volume.

Stop everything, whichever profiles you started:

```bash
docker compose --profile "*" down
```

## Start-up

| Symptom | Likely cause | Fix |
|---|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop isn't running. | Start Docker Desktop, wait for the whale icon to settle, retry. |
| `ports are not available` / `address already in use` on port 80 | Another program uses port 80 (IIS, Apache, nginx, another Docker project). | Stop it, or run `scripts/preflight.sh` to see what is in the way. Windows: `netstat -ano \| findstr :80`. Mac/Linux: `lsof -i :80`. |
| `docker compose up --wait` times out | A service is unhealthy, usually the NameNode, or the machine is out of memory. | `docker compose ps`, then `docker compose logs namenode`. See [memory](memory.md). |
| First start takes many minutes | Images are downloaded once (about 2 GB for core, more per add-on). | Wait. Later starts take under a minute. |
| `no matching manifest` / `exec format error` | An image for another CPU type. | Use the repo's `compose.yaml` unchanged; it sets the platform for each service. |
| `*.localhost` doesn't open | Your browser or OS doesn't resolve `.localhost`. | Use Chrome, Edge or Firefox. Or test with `curl -H "Host: hdfs.localhost" http://127.0.0.1/`. |
| Every `*.localhost` returns an empty reply, though `docker compose ps` is fine | Docker's port forwarder got stuck. | `docker compose restart proxy`. |
| `up` says `... is not healthy` right after a restart | HDFS is in safe mode for a few seconds. | Wait; `docker compose up -d --wait` again. |

## HDFS

| Symptom | Likely cause | Fix |
|---|---|---|
| `Name node is in safe mode` | HDFS just started and is read-only for a short time. | `hdfs dfsadmin -safemode wait`, then retry. |
| `put: ... File exists` | The target is already there. | `hdfs dfs -put -f file /dir/` or remove the old one with `hdfs dfs -rm`. |
| `could only be written to 0 of the 1 minReplication nodes` | No DataNode is running or it has no space. | `docker compose ps datanode`; `hdfs dfsadmin -report`. |
| `Incompatible clusterIDs` in the DataNode log | The NameNode volume was recreated but the DataNode's still has the old ID. | Wipe both: `docker compose --profile "*" down -v`, then `up` again. |
| UI download link opens nothing | Browser was sent to a DataNode name it can't resolve. | Use the link from `http://hdfs.localhost`, which points at `dn1.localhost`; or `hdfs dfs -get` from the shell. |
| `Permission denied` | Only on your own changes to `dfs.permissions.enabled`. | The lab setup has permissions off; undo the change. |
| `Under replicated blocks` after you stopped a DataNode (lab 04) | Expected. | Wait about 90 seconds and run `hdfs fsck /`. |

## YARN and MapReduce

| Symptom | Likely cause | Fix |
|---|---|---|
| Job stays `ACCEPTED` | No memory free for its ApplicationMaster, or another job holds the cluster. | Wait for the other job, or see [lab 10](../labs/10-tuning-yarn/README.md). If nothing else is running, check [memory](memory.md). |
| `Invalid resource request ... maximum allowed allocation` | A container asked for more than `yarn.scheduler.maximum-allocation-mb` (768). | Lower the request, for example `-Dmapreduce.map.memory.mb=256`. |
| `Container killed ... exit code 137` | Out of memory: Docker or the kernel killed it. | Give Docker more memory, run one job at a time. |
| `Container killed on request. Exit code is 143` | YARN stopped the container (finished, killed by you, or over its memory). | Read the task log: `yarn logs -applicationId <id>` (see [lab 03](../labs/03-job-history-and-logs/README.md)) or `docker compose logs nodemanager`. |
| `Output directory ... already exists` | MapReduce won't overwrite. | `hdfs dfs -rm -r <folder>`, rerun. |
| `Application failed 2 times due to AM Container ... exited with exitCode: 1` | The ApplicationMaster crashed. | Open the application's page, then its log; usual cause is memory or a wrong `HADOOP_MAPRED_HOME`. |
| A **Logs** or **History** link in the YARN UI returns 502 | The link goes to the history server, which only runs with the `history` profile. | `docker compose --profile history up -d --wait`, or read the logs with `yarn logs`. |
| NodeManager gone from **Nodes** | It was killed under memory pressure. | `docker compose restart nodemanager`. |
| Everything is very slow on a Mac with Apple Silicon | The Hadoop image is Intel-only and is emulated. | See [Windows and Mac specifics](#windows-and-mac-specifics). |

## Notebook and Spark

| Symptom | Likely cause | Fix |
|---|---|---|
| 502 at `jupyter.localhost` | The notebook isn't running yet or crashed. | `docker compose --profile notebook up -d --wait`; `docker compose logs notebook`. |
| 502 at `spark.localhost` | Spark's UI only exists while a notebook holds a Spark session. | Run a cell that creates a `SparkSession`. |
| Kernel dies / restarts | Out of memory. | Close other notebooks; give Docker more memory. |
| `Connection refused` to `namenode:8020` | HDFS isn't up yet. | `docker compose ps namenode`. |
| `PATH_ALREADY_EXISTS` / `path ... already exists` | Writing to a folder that exists. | `.mode("overwrite")` or remove it with `hdfs dfs -rm -r`. |
| A lab notebook isn't in JupyterLab's file browser | JupyterLab only shows `workspace/`. | Copy it in: `docker compose exec notebook cp /labs/<lab>/<name>.ipynb /workspace/`. |
| `Cannot call methods on a stopped SparkContext` | The notebook's last cell ran `spark.stop()`. | Run the notebook's first code cell again. |
| `ModuleNotFoundError` for a package | Not in the image. | `%pip install <package>` in a cell (lasts until the container is recreated), or add it to `notebook/pyproject.toml` and rebuild. |

## Hive

| Symptom | Likely cause | Fix |
|---|---|---|
| beeline: `Connection refused` | HiveServer2 takes 1 to 2 minutes to start. | `docker compose --profile hive up -d --wait` returns when it is ready; retry. |
| My Hive query isn't in the YARN UI | Expected. Queries run inside HiveServer2 (Tez local mode). | Nothing to fix; see lab 07. |
| `Another instance of Derby may have already booted the database` | HiveServer2 was killed uncleanly. | `docker compose restart hiveserver2`; if it persists, `down -v`. |
| `Table already exists` | You ran `CREATE` twice. | `CREATE TABLE IF NOT EXISTS` or `DROP TABLE`. |
| `Permission denied` / `Unable to move source` | Folder in HDFS belongs to someone else. | Use a path under `/user/lab/` and run `hdfs dfs -chmod -R a+rwx /user/lab` in the namenode shell (lab 07, step 1). |

## Kafka

| Symptom | Likely cause | Fix |
|---|---|---|
| `Failed to find data source: kafka` | Notebook image lacks the Kafka connector jars. | `docker compose --profile notebook build notebook`, then `up -d`. |
| `Connection to node -1 ... could not be established` | Kafka isn't running, or you used `localhost:9092` inside a container. | Inside containers use `kafka:9092`; check `docker compose ps kafka`. |
| `kafka-topics.sh: command not found` | Wrong path. | Use the full path `/opt/kafka/bin/kafka-topics.sh`. |
| Streaming query fails with `offset was changed from X to Y` | The topic was recreated but the checkpoint remembers the old one. | Use new `checkpointLocation` and output folders, or delete both from HDFS. |
| No output from the stream | Nothing was produced, or `startingOffsets` is `latest`. | Produce lines first; use `earliest` for old messages. |
| Parquet count doesn't grow on re-run | No new messages since the last run. | That's the checkpoint working; produce more lines. |

## Windows and Mac specifics

| Symptom | Likely cause | Fix |
|---|---|---|
| Port 80 busy (Windows) | IIS, World Wide Web Publishing Service, or Skype. | Stop the service (`net stop http` needs admin) or free the port. |
| Port 80 busy (Mac) | Another web server. | `lsof -i :80`, stop it. |
| `bash\r: No such file` or `$'\r': command not found` | Git turned LF line endings into CRLF (Windows). | `git config --global core.autocrlf input`, then re-clone, or `git rm --cached -r . && git reset --hard`. The repo's `.gitattributes` asks for LF. |
| Slow first job on Apple Silicon (a minute or more) | The Hadoop image runs under amd64 emulation. | Normal. In Docker Desktop **Settings → General** enable "Use Rosetta for x86_64/amd64 emulation" if offered. The notebook and Kafka run natively. |
| Containers exit with code 137 or `OOMKilled` | Docker has too little memory. | See [memory](memory.md) for how to raise it. |
| Old data or odd errors after changing config | Volumes still hold the previous cluster. | `docker compose --profile "*" down -v`, then `up` (this erases HDFS). |
| Windows: slow file access in `workspace/` | Project is on the Windows side of WSL2. | Clone inside the WSL2 file system (`~/hands-on-hadoop`), not under `/mnt/c`. |

Still stuck? Open an issue with the output of `docker compose ps`, `docker version`, and the last lines of `docker compose logs <service>`.
