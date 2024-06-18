#!/bin/sh

# Ensure we have some virus data, otherwise clamd refuses to start
if [ ! -f "/var/lib/clamav/main.cvd" ]; then
    echo "Updating initial database"
    freshclam --foreground --stdout --user="docker"
fi

echo "Starting Freshclamd"
freshclam --checks="${FRESHCLAM_CHECKS:-1}" --daemon --foreground --stdout --user="docker" &

echo "Starting ClamAV..."

clamd --foreground &

# Wait for ClamAV daemon to start
sleep 5

echo "ClamAV daemon started."

# Wait forever (or until canceled)
exec tail -f "/dev/null"
