#!/bin/sh
while true; do
    /app/fetch_and_scan.sh
    python3 /app/generate_report.py
    sleep 300   # 5 minutes
done