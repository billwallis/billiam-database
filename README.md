<div align="center">

[![uv](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/uv/main/assets/badge/v0.json)](https://github.com/astral-sh/uv)
[![Docker](https://img.shields.io/badge/Docker-28.4-blue.svg)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/Python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![tests](https://github.com/billwallis/billiam-database/actions/workflows/tests.yaml/badge.svg)](https://github.com/billwallis/billiam-database/actions/workflows/tests.yaml)
[![GitHub last commit](https://img.shields.io/github/last-commit/billwallis/billiam-database)](https://shields.io/badges/git-hub-last-commit)

[![pre-commit.ci status](https://results.pre-commit.ci/badge/github/billwallis/billiam-database/main.svg)](https://results.pre-commit.ci/latest/github/billwallis/billiam-database/main)
[![DuckDB](https://img.shields.io/badge/DuckDB-1.4-teal.svg)](https://duckdb.org/)
[![Metabase](https://img.shields.io/badge/Metabase-0.47-teal.svg)](https://www.metabase.com/)

</div>

---

# Billiam's Database 🧙‍♂️

OLAP database project for life admin.

## About

As part of my life admin, I keep track of:

- Every transaction I make at an item level (since 2018-01-18)
- On the job, what I'm working on every 15 minutes (since 2019-04-23)

Note that the job tracker is my [daily-tracker](https://github.com/billwallis/daily-tracker) project.

## Setup

Since this is a personal project, I don't expect anyone else to do this, but I'm still documenting it for myself (I have a very, very bad memory).

### Pre-requisites

This project requires the following three tools to be installed:

- [Python](https://www.python.org/downloads/)
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- [Docker](https://www.docker.com/) (only if you want to use [Metabase](https://www.metabase.com/))

The required versions are specified in the badges at the top of this README.

### Installation (SQLMesh)

After cloning the repo, install the dependencies and enable [pre-commit](https://pre-commit.com/):

```shell
uvx --with poethepoet poe install
```

This will install several packages, including the task runner [Poe the Poet](https://poethepoet.natn.io/index.html). The tasks are defined in the `pyproject.toml` file.

Pipeline changes need to be applied via a plan:

```
poe plan
```

...and the pipeline can be run with the `run` command:

```
poe run
```

### Installation (Metabase)

> [!WARNING]
>
> The DuckDB driver for Metabase is a community driver. This means that it might not work in all circumstances.

[Metabase](https://www.metabase.com/) is a tool for visualising data.

In this project, Metabase is run in a Docker container; run the following command:

```shell
# start
poe docker-up

# stop
poe docker-down
```

This will make Metabase available at:

- [http://localhost:3000](http://localhost:3000)

> [!WARNING]
>
> There are two important notes about the current Metabase configuration:
>
> - Since [DuckDB](https://duckdb.org/) only supports one connection at a time, you can't use Metabase and run the pipelines at the same time.
> - The Metabase data is stored locally in the `dockerfiles/metaduck-data` directory so that it persists between container restarts.
