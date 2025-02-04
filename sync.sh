#!/bin/bash

HOST_BASE=<HOST_BASE>
MAX_NODES=<MAX_NODES>

CURRENT_HOST=$(hostname)
DEST_HOSTS=()
for i in $(seq 1 $MAX_NODES); do
	HOST="$HOST_BASE$i"
    if [[ "$HOST" != "$CURRENT_HOST" ]]; then
        DEST_HOSTS+=("$HOST")
    fi
done

inotifywait -m -e modify,create,delete,move /opt/test.sh /opt/shared/ --format '%w%f' | while read FILE; do
    for host in "${DEST_HOSTS[@]}"; do
        rsync -avz -e "ssh -o StrictHostKeyChecking=no" "$FILE" "$host:$FILE"
    done
done
