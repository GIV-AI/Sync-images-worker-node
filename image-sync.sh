#!/bin/bash

###############################################################################
# IMAGE SYNC SCRIPT - PREFIX FILTERED WITH EXACT TAG CHECK
# Sync images between two Kubernetes worker nodes
###############################################################################

# --- Load Config File ---
CONFIG_FILE="$(dirname "$0")/image-sync.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# --- Acquire Lock ---
LOCK_FILE="/var/run/image-sync.lock"
exec 200>"$LOCK_FILE"
flock -n 200 || {
    echo "ERROR: Script already running. Lock active: $LOCK_FILE"
    exit 1
}

# --- Prepare Logs ---
mkdir -p "$LOG_DIR"

LOGFILE="$LOG_DIR/image-sync.log"
SUCCESS_LIST="$LOG_DIR/success_images.log"
FAILED_LIST="$LOG_DIR/failed_images.log"

# Temporary session files for accurate session counting
TMP_SUCCESS_LIST=$(mktemp)
TMP_FAILED_LIST=$(mktemp)

log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOGFILE"
}

append_success() {
    local NODE="$1"
    local IMAGE="$2"
    echo "[$(date '+%F %T')] $NODE $IMAGE - SUCCESS" | tee -a "$LOGFILE" >> "$TMP_SUCCESS_LIST"
    echo "[$(date '+%F %T')] $NODE $IMAGE - SUCCESS" >> "$SUCCESS_LIST"
}

append_failed() {
    local NODE="$1"
    local IMAGE="$2"
    echo "[$(date '+%F %T')] $NODE $IMAGE - FAILED" | tee -a "$LOGFILE" >> "$TMP_FAILED_LIST"
    echo "[$(date '+%F %T')] $NODE $IMAGE - FAILED" >> "$FAILED_LIST"
}

###############################################################################
# SSH CHECK
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
# Pull image on node (with timeout)
###############################################################################
pull_image() {
    local NODE="$1"
    local IMAGE="$2"

    log "Pulling $IMAGE on $NODE"

    ssh -o ConnectTimeout=20 "$NODE" "timeout $TIME_OUT crictl pull $IMAGE" \
        >>"$LOGFILE" 2>&1
    local EXIT_CODE=$?

    if [ $EXIT_CODE -eq 124 ]; then
        log "TIMEOUT: Pulling $IMAGE on $NODE exceeded timeout"
        append_failed "$NODE" "$IMAGE (TIMEOUT)"
    elif [ $EXIT_CODE -eq 0 ]; then
        log "SUCCESS: $IMAGE on $NODE"
        append_success "$NODE" "$IMAGE"
    else
        log "FAILED: $IMAGE on $NODE (Exit code: $EXIT_CODE)"
        append_failed "$NODE" "$IMAGE (EXIT $EXIT_CODE)"
    fi
}

###############################################################################
# Pull images in parallel with MAX_PARALLEL
###############################################################################
pull_images_parallel() {
    local NODE="$1"
    shift
    local IMAGES=("$@")
    local PULLED=0

    log "Pulling ${#IMAGES[@]} missing images on $NODE..."

    for img in "${IMAGES[@]}"; do
        [ -z "$img" ] && { log "Skipping empty image entry"; continue; }
        pull_image "$NODE" "$img" &
        ((PULLED++))

        # Limit parallel jobs
        while [ "$(jobs -rp | wc -l)" -ge "$MAX_PARALLEL" ]; do
            sleep 1
        done
    done

    wait

    # Log "no new image found" but do NOT count it
    if [ $PULLED -eq 0 ]; then
        echo "[$(date '+%F %T')] $NODE ---- no new image found ----" | tee -a "$LOGFILE"
    else
        echo "[$(date '+%F %T')] $NODE ---- pull operations completed ----" >> "$LOGFILE"
    fi
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

# Determine missing images
mapfile -t missing_on_node1 <<< "$(comm -13 <(echo "$list1" | sort) <(echo "$list2" | sort))"
mapfile -t missing_on_node2 <<< "$(comm -23 <(echo "$list1" | sort) <(echo "$list2" | sort))"

# Cleanup empty entries
missing_on_node1=($(printf "%s\n" "${missing_on_node1[@]}" | sed '/^\s*$/d'))
missing_on_node2=($(printf "%s\n" "${missing_on_node2[@]}" | sed '/^\s*$/d'))

# No sync needed
if [ ${#missing_on_node1[@]} -eq 0 ] && [ ${#missing_on_node2[@]} -eq 0 ]; then
    log "All images are already synced"
    echo "[$(date '+%F %T')] $NODE1 ---- no new image found ----" | tee -a "$LOGFILE"
    echo "[$(date '+%F %T')] $NODE2 ---- no new image found ----" | tee -a "$LOGFILE"
else
    # Pull missing images
    log "Pulling missing images on $NODE1..."
    pull_images_parallel "$NODE1" "${missing_on_node1[@]}"

    log "Pulling missing images on $NODE2..."
    pull_images_parallel "$NODE2" "${missing_on_node2[@]}"
fi

###############################################################################
# Summary (counts only real pulls)
###############################################################################
SUCCESS_COUNT=$(grep -c " - SUCCESS" "$TMP_SUCCESS_LIST")
FAILED_COUNT=$(grep -c " - FAILED" "$TMP_FAILED_LIST")

log "=== SUMMARY ==="
log "Successful pulls (this session): $SUCCESS_COUNT"
log "Failed pulls (this session): $FAILED_COUNT"
log "=== IMAGE SYNC COMPLETE ==="

# Cleanup temporary files
rm -f "$TMP_SUCCESS_LIST" "$TMP_FAILED_LIST"
