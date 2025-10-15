#!/usr/bin/env python3
# metrics_collector.py - Collect torrent performance data

import sqlite3
import time
import qbittorrentapi
import json
import os
from datetime import datetime

# Configuration
DB_PATH = os.path.expanduser("~/torrent_metrics.db")
QBT_HOST = "localhost"
QBT_PORT = 8080
QBT_USERNAME = "admin"  # Replace with your username
QBT_PASSWORD = "adminadmin"  # Replace with your password

# Connect to qBittorrent
qbt = qbittorrentapi.Client(
    host=QBT_HOST,
    port=QBT_PORT,
    username=QBT_USERNAME,
    password=QBT_PASSWORD
)

# Connect to database
conn = sqlite3.connect(DB_PATH)
c = conn.cursor()

# Get current timestamp
current_time = int(time.time())

# Get all torrents
torrents = qbt.torrents_info()

for torrent in torrents:
    # Check if torrent exists in database
    c.execute("SELECT hash FROM torrents WHERE hash = ?", (torrent.hash,))
    exists = c.fetchone()

    if not exists:
        # Add new torrent
        tracker = torrent.tracker.split('/')[2] if '//' in torrent.tracker else torrent.tracker

        c.execute(
            "INSERT INTO torrents VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                torrent.hash,
                torrent.name,
                tracker,
                torrent.category,
                torrent.size,
                current_time,
                current_time if torrent.progress == 1 else None,
                torrent.num_seeds,
                torrent.num_leechs
            )
        )
    elif torrent.progress == 1:
        # Update completion time if needed
        c.execute(
            "UPDATE torrents SET completion_time = ? WHERE hash = ? AND completion_time IS NULL",
            (current_time, torrent.hash)
        )

    # Add metrics data
    c.execute(
        "INSERT INTO metrics VALUES (?, ?, ?, ?, ?, ?, ?)",
        (
            torrent.hash,
            current_time,
            torrent.ratio,
            torrent.uploaded,
            torrent.downloaded,
            torrent.num_seeds,
            torrent.num_leechs
        )
    )

# Commit changes and close connection
conn.commit()
conn.close()

print(f"Metrics collected at {datetime.fromtimestamp(current_time).strftime('%Y-%m-%d %H:%M:%S')}")