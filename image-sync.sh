#!/bin/bash

###############################################################################
# IMAGE SYNC SCRIPT - PREFIX FILTERED WITH EXACT TAG CHECK
# Sync images between two Kubernetes worker nodes
# Only images starting with configured PREFIX1 and PREFIX2 are synced
###############################################################################

# --- Load Config File ---
CONFIG_FILE="$(dirname "$0")/image-sync.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# --- Prepare Logs ---
mkdir -p "$LOG_DIR"

LOGFILE="$LOG_DIR/image-sync_$(date +%F_%H-%M-%S).log"
SUCCESS_LIST="$LOG_DIR/success_images.txt"
FAILED_LIST="$LOG_DIR/failed_images.txt"

> "$SUCCESS_LIST"
> "$FAILED_LIST"

log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOGFILE"
}

###############################################################################
# SSH CHECK - Optimized (single call, no repeated checks)
###############################################################################
check_ssh() {
    local NODE="$1"

    log "Checking SSH to $NODE"

    if ssh -o BatchMode=yes -o ConnectTimeout=10 "$NODE" "echo ok" >/dev/null 2>>"$LOGFILE"; then
        log "SSH OK: $NODE"
    else
        log "ERROR: Cannot connect to $NODE"
        exit 1
    fi
}

###############################################################################
# Fetch & extract images
###############################################################################
get_images() {
    ssh -o ConnectTimeout=10 "$1" "crictl images -o json" 2>>"$LOGFILE"
}

extract_images() {
    echo "$1" | jq -r '.images[].repoTags[]?' \
        | grep -E "^($PREFIX1|$PREFIX2)" 2>>"$LOGFILE"
}

###############################################################################
# Check if image exists on node
###############################################################################
image_exists() {
    local NODE="$1"
    local IMAGE="$2"

    ssh -o ConnectTimeout=10 "$NODE" \
        "crictl images -o json | jq -r '.images[].repoTags[]?' | grep -Fxq '$IMAGE'"
    return $?
}

###############################################################################
# Pull image on node
###############################################################################
pull_image() {
    local NODE="$1"
    local IMAGE="$2"

    log "Pulling $IMAGE on $NODE"

    ssh -o ConnectTimeout=20 "$NODE" "crictl pull $IMAGE" >>"$LOGFILE" 2>&1

    if [ $? -eq 0 ]; then
        log "SUCCESS: $IMAGE on $NODE"
        echo "$IMAGE" >> "$SUCCESS_LIST"
    else
        log "FAILED: $IMAGE on $NODE"
        echo "$IMAGE" >> "$FAILED_LIST"
    fi
}

###############################################################################
# Pull images in parallel with limit
###############################################################################
pull_images_parallel() {
    local NODE="$1"
    shift
    local IMAGES=("$@")

    for img in "${IMAGES[@]}"; do
        [ -z "$img" ] && { log "Skipping empty image entry"; continue; }

        if image_exists "$NODE" "$img"; then
            log "Already exists: $img on $NODE"
            continue
        fi

        pull_image "$NODE" "$img" &

        while [ "$(jobs -rp | wc -l)" -ge "$MAX_PARALLEL" ]; do
            sleep 1
        done
    done

    wait
}

###############################################################################
# Main Script Logic
###############################################################################
log "=== IMAGE SYNC STARTED ==="

# SSH check
check_ssh "$NODE1"
check_ssh "$NODE2"

# Fetch images
log "Fetching images from nodes..."
images_node1=$(get_images "$NODE1")
images_node2=$(get_images "$NODE2")

list1=$(extract_images "$images_node1")
list2=$(extract_images "$images_node2")

log "Images on $NODE1: $(echo "$list1" | wc -l)"
log "Images on $NODE2: $(echo "$list2" | wc -l)"

# Compare images between nodes
mapfile -t missing_on_node1 <<< "$(comm -13 <(echo "$list1" | sort) <(echo "$list2" | sort))"
mapfile -t missing_on_node2 <<< "$(comm -23 <(echo "$list1" | sort) <(echo "$list2" | sort))"

# Pull missing images
log "Pulling missing images on $NODE1..."
pull_images_parallel "$NODE1" "${missing_on_node1[@]}"

log "Pulling missing images on $NODE2..."
pull_images_parallel "$NODE2" "${missing_on_node2[@]}"

# Summary
log "=== SUMMARY ==="
log "Successful pulls: $(wc -l < "$SUCCESS_LIST")"
log "Failed pulls: $(wc -l < "$FAILED_LIST")"

log "=== IMAGE SYNC COMPLETE ==="
log "Full log: $LOGFILE"
