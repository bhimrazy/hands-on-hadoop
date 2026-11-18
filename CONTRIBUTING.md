# Contributing

Thanks for helping make these labs better. Typo fixes, clearer wording and new "break it on purpose" ideas are all welcome.

## How a lab is built

Each lab lives in `labs/NN-slug/` and has three parts that must agree with each other:

| Part | What it is |
|---|---|
| `README.md` | The walkthrough: start, steps with expected output, check yourself, break it, clean up |
| `check.sh` | The "check yourself" script. It runs inside the namenode container and prints `PASS` or `FAIL` per check |
| `tests/labs/NN.sh` | The CI driver. It does the lab's steps non-interactively, then runs `check.sh` |

The first lines of `tests/labs/NN.sh` say which stack CI starts:

```bash
# profiles: history
# services: namenode datanode
```

`profiles` is empty for the core stack. `services` is optional and limits what `up` starts.

If you change a step in a README, change the matching line in `tests/labs/NN.sh` and `check.sh`.

## Run the linters locally

CI runs the same checks as `lint.yml`. The quick ones are easy to run yourself:

```bash
docker compose config -q
docker compose --profile "*" config -q
shellcheck -x scripts/*.sh labs/*/*.sh tests/labs/*.sh
```

Notebooks under `labs/` are committed without outputs. Clear them first:

```bash
jupyter nbconvert --clear-output --inplace labs/NN-slug/notebook.ipynb
```

## Full stacks are tested in CI

Starting Hadoop, Hive or Kafka needs several GB of memory, so the full lab tests run on GitHub Actions (`labs.yml`), not on your laptop. Open a pull request and watch the `lab NN` jobs. The arm64 job runs nightly and on manual dispatch only.

You are welcome to run a lab by hand while you write it. Just don't feel you have to run all ten.

## Pinning and the 7-day rule

Everything that gets downloaded and run is pinned:

- Docker images: `tag@sha256:digest`
- GitHub Actions: full commit SHA with a `# vX.Y.Z` comment
- Downloaded jars: `ADD --checksum=sha256:...`
- Python packages: `uv.lock`, installed with `--frozen`

Use releases that are at least 7 days old, unless it is a security fix. Dependabot is set up with a 7-day cooldown for the same reason. Never turn off a checksum or TLS check to make something work. Open an issue instead.

## Style

- Folders and files use kebab-case. Line endings are LF (`.gitattributes` handles this).
- Short sentences. Show the output the reader should see.
- Code comments explain why, not what. Most code needs none.

## Commits and pull requests

- One logical change per commit, imperative subject under about 70 characters: `Explain why jobs sit in ACCEPTED`.
- The pull request template asks what the change does. Keep it short.
- By contributing you agree your work is released under the [Apache-2.0 license](LICENSE).
