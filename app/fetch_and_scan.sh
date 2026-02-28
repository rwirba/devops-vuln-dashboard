#!/bin/sh
set -e  # exit on error

NAMESPACE="${DOCKERHUB_NAMESPACE:-ryanandevlab}"
USERNAME="${DOCKERHUB_USERNAME}"
TOKEN="${DOCKERHUB_TOKEN}"

PAGE_SIZE=100

echo "[$(date)] Fetching all repositories and tags from Docker Hub namespace: $NAMESPACE"

if [ -z "$USERNAME" ] || [ -z "$TOKEN" ]; then
    echo "⚠️ WARNING: DOCKERHUB_USERNAME or DOCKERHUB_TOKEN not set. Falling back to anonymous (may return 0 repos)."
    AUTH_HEADER=""
else
    AUTH_HEADER="-H \"Authorization: Bearer $TOKEN\""
fi

# Fetch all repos (with pagination)
REPOS=""
PAGE=1
while true; do
    RESPONSE=$(curl -s $AUTH_HEADER \
        "https://hub.docker.com/v2/repositories/${NAMESPACE}/?page_size=${PAGE_SIZE}&page=${PAGE}")

    # Check for API error
    if echo "$RESPONSE" | grep -q '"detail"'; then
        echo "API Error: $(echo "$RESPONSE" | jq -r '.detail // "Unknown error"')"
        break
    fi

    NEW_REPOS=$(echo "$RESPONSE" | jq -r '.results[]?.name // empty')
    REPOS="$REPOS $NEW_REPOS"

    NEXT=$(echo "$RESPONSE" | jq -r '.next // empty')
    if [ -z "$NEXT" ]; then break; fi
    PAGE=$((PAGE + 1))
done

if [ -z "$REPOS" ]; then
    echo "⚠️ No repositories found or API issue. Using previous list."
    # Optional: exit here or continue with old list
else
    echo "Found $(echo "$REPOS" | wc -w | xargs) repositories."

    # Clear and rebuild image list with ALL tags
    > /data/images.list

    for repo in $REPOS; do
        echo "Fetching tags for ${NAMESPACE}/${repo}..."

        TAG_PAGE=1
        while true; do
            TAG_RESPONSE=$(curl -s $AUTH_HEADER \
                "https://hub.docker.com/v2/repositories/${NAMESPACE}/${repo}/tags/?page_size=${PAGE_SIZE}&page=${TAG_PAGE}")

            TAGS=$(echo "$TAG_RESPONSE" | jq -r '.results[]?.name // empty')

            for tag in $TAGS; do
                echo "${NAMESPACE}/${repo}:${tag}" >> /data/images.list
            done

            TAG_NEXT=$(echo "$TAG_RESPONSE" | jq -r '.next // empty')
            if [ -z "$TAG_NEXT" ]; then break; fi
            TAG_PAGE=$((TAG_PAGE + 1))
        done
    done
fi

IMAGE_COUNT=$(wc -l < /data/images.list)
echo "Dynamic image list ready (${IMAGE_COUNT} image:tag combinations):"
cat /data/images.list | head -n 20   # show first 20
[ $IMAGE_COUNT -gt 20 ] && echo "... and $(($IMAGE_COUNT - 20)) more"

# Run Trivy scans on the fresh list
/app/scan_all.sh