# Security policy

This repository is a set of local learning labs. The services run on your own machine and the web UIs are bound to `127.0.0.1` only. Do not expose them to a network: Hadoop, Hive and Kafka are started here without authentication.

## Reporting a vulnerability

Please report privately through GitHub: open the **Security** tab of this repository and choose **Report a vulnerability**
([direct link](https://github.com/bhimrazy/hands-on-hadoop/security/advisories/new)).

If private reporting is not available to you, open an issue that says only that you have a security concern and I will arrange a private channel. Please do not put details in a public issue.

You can expect a first reply within a week.

## Scope

In scope: the compose file, Dockerfile, scripts, CI workflows, and pinned dependencies in this repo, for example a script that runs untrusted input or a workflow that leaks a token.

Out of scope: the lack of authentication in the upstream Hadoop, Spark, Hive or Kafka images when used as documented on localhost. Report vulnerabilities in those projects to the projects themselves.

## Supply chain

Images are pinned by digest, GitHub Actions by commit SHA, and jars by checksum. Dependabot proposes updates after a 7-day cooldown. See [CONTRIBUTING.md](CONTRIBUTING.md).
