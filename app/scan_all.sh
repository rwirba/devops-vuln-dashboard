#!/bin/sh
set -euo pipefail  # exit on error, undefined vars, pipe failures

mkdir -p /data/scans

echo "[$(date '+%Y-%m-%d %H:%M:%S UTC')] Starting vulnerability scan cycle..."

# Check if images.list exists and has content
if [ ! -s /data/images.list ]; then
    echo "  ⚠️  WARNING: /data/images.list is empty or missing. No images will be scanned."
    echo "  Please add images using: echo 'image:tag' >> /data/images.list"
    exit 1
fi

# Optional: Update vulnerability DB only if it doesn't exist or is old
# (first run downloads ~500MB, later runs are very fast)
if [ ! -f /root/.cache/trivy/db/trivy.db ]; then
    echo "  → Downloading Trivy vulnerability database (first run)..."
    trivy image --download-db-only --quiet || {
        echo "  ❌ Failed to download Trivy DB. Scans may be inaccurate."
    }
fi

scan_count=0
failed_count=0

while IFS= read -r img || [ -n "$img" ]; do
    # Skip empty lines and comments
    img=$(echo "$img" | tr -d '\r' | xargs)
    [ -z "$img" ] && continue
    [ "${img#\#}" != "$img" ] && continue  # skip lines starting with #

    scan_count=$((scan_count + 1))
    safe_name=$(echo "$img" | sed 's/[^[:alnum:]_.-]/_/g' | tr '[:upper:]' '[:lower:]')
    output_file="/data/scans/${safe_name}.json"

    echo "  → [$scan_count] Scanning $img ..."

    # Try scan once, retry once on failure
    if ! trivy image \
        --timeout 20m \
        --scanners vuln \
        --format json \
        --output "$output_file" \
        --skip-db-update \
        "$img" 2>&1 | grep -v "unknown revision" | grep -v "failed to fetch"; then

        echo "    ⚠️  Scan failed for $img — retrying once..."
        sleep 3
        if ! trivy image \
            --timeout 20m \
            --scanners vuln \
            --format json \
            --output "$output_file" \
            --skip-db-update \
            "$img"; then
            echo "    ❌  Retry failed for $img"
            failed_count=$((failed_count + 1))
            rm -f "$output_file"  # remove partial/empty file
        else
            echo "    ✓  Retry succeeded"
        fi
    else
        echo "    ✓  Scan completed"
    fi

done < /data/images.list

echo "[$(date '+%Y-%m-%d %H:%M:%S UTC')] Scan cycle completed."
echo "  Scanned: $scan_count images | Failed: $failed_count"

# Optional: touch a file to signal scan completed (can be used for monitoring)
touch /data/last_scan_complete