#!/bin/sh
mkdir -p /data/scans
echo "[$(date)] Starting vulnerability scan cycle..."

for img in $(cat /data/images.list | grep -v '^#' | tr -d '\r'); do
    [ -z "$img" ] && continue
    safe_name=$(echo "$img" | sed 's/[^[:alnum:]_.-]/_/g')
    echo "  → Scanning $img ..."
    trivy image \
        --quiet \
        --scanners vuln \
        --format json \
        --output "/data/scans/${safe_name}.json" \
        "$img" || echo "    ⚠️  Scan failed for $img (check logs)"
done

echo "[$(date)] Scan cycle completed."