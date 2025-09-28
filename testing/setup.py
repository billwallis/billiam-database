"""
Setup for CI.

This is quick and dirty, but it works for now.
"""

import os
import pathlib

import duckdb

CWD = pathlib.Path(os.getenv("GITHUB_WORKSPACE"))

conn = duckdb.connect(database=CWD / "billiam_database/billiam.duckdb")
conn.close()

# This is a temporary fix -- this should not be a seed because it includes
# sensitive data, so just need to refactor and move it somewhere better
counterparty_exclusions = CWD / "billiam_database/models/seeds/data/counterparty_exclusions.csv"
counterparty_exclusions.touch()
counterparty_exclusions.write_text("counterparty")
