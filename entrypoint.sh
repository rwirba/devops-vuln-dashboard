#!/bin/sh
set -e

mkdir -p /data/scans /usr/share/nginx/html
if [ ! -f /data/images.list ]; then
    cp /app/default_images.list /data/images.list
fi
if [ ! -f /data/report.json ]; then
    echo '{"images":[],"last_update":"Never"}' > /data/report.json
fi

# Copy initial report so dashboard loads immediately
cp /data/report.json /usr/share/nginx/html/report.json

echo "DevOps Vulnerability Dashboard starting..."
echo "Images to scan: $(cat /data/images.list | wc -l)"
exec supervisord -c /etc/supervisord.conf