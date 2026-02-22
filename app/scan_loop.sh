#!/bin/sh
while true; do
    /app/scan_all.sh
    python3 /app/generate_report.py
    sleep 300   # 5 minutes
done