"""
Generate tests/fixtures/FingerText2_seed.db3 — a minimal seed database for
functional.py. Run this script any time you need to regenerate the fixture.

Schema mirrors dataBaseInit() in PluginDefinition.cpp:
    CREATE TABLE snippets (tag TEXT, tagType TEXT, snippet TEXT, package TEXT)
"""

import os
import sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
OUT  = os.path.join(HERE, "FingerText2_seed.db3")

if os.path.exists(OUT):
    os.remove(OUT)

con = sqlite3.connect(OUT)
con.execute(
    "CREATE TABLE snippets (tag TEXT, tagType TEXT, snippet TEXT, package TEXT)"
)
con.execute(
    "INSERT INTO snippets (tag, tagType, snippet, package) VALUES (?, ?, ?, ?)",
    (
        "testtrigger",
        "GLOBAL",
        "Hello from FingerText2 $[![ placeholder ]!] [>END<]",
        "test",
    ),
)
con.commit()
con.close()

print(f"Written: {OUT}")
