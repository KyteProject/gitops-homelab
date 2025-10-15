#!/bin/bash
# setup_tracker.sh - Create SQLite database for tracking torrent performance

sqlite3 ~/torrent_metrics.db << 'EOF'
CREATE TABLE IF NOT EXISTS torrents (
    hash TEXT PRIMARY KEY,
    name TEXT,
    tracker TEXT,
    category TEXT,
    size_bytes INTEGER,
    added_time INTEGER,
    completion_time INTEGER,
    initial_seeders INTEGER,
    initial_leechers INTEGER
);

CREATE TABLE IF NOT EXISTS metrics (
    hash TEXT,
    timestamp INTEGER,
    ratio REAL,
    uploaded_bytes INTEGER,
    downloaded_bytes INTEGER,
    seeders INTEGER,
    leechers INTEGER,
    FOREIGN KEY (hash) REFERENCES torrents(hash)
);

CREATE INDEX IF NOT EXISTS idx_metrics_hash ON metrics(hash);
CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics(timestamp);
EOF

echo "Torrent metrics database created at ~/torrent_metrics.db"