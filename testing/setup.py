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
