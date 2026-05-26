#!/bin/bash
#===============================================
# Linux VPS daily cleanup — RAM + Docker + Kubernetes + zombies + logs
#
# Designed for a single-host VPS that runs Docker and/or K3s. Suggested cron:
#   30 4 * * *  /usr/local/bin/vps-cleanup-daily.sh
#
# Sections:
#   1) RAM      — drop page cache, reset swap if > 500MB used
#   2) Zombies  — kill ALLOWLISTED parent processes of <defunct> children
#                 (default allowlist: chrome variants + GNU timeout)
#   3) Docker   — full builder prune, image prune, volume prune, network prune
#   4) K8s      — delete Failed/Succeeded pods, prune containerd images,
#                 wipe pod logs older than 3 days
#   5) System   — journal vacuum, /tmp + /var/tmp + nginx logs + apt cache,
#                 truncate the script's own log if it grows past 100MB
#
# The zombie reaper is intentionally conservative: it only sends SIGKILL to
# parent PIDs whose `comm` name appears in $ZOMBIE_PARENT_ALLOWLIST.
#===============================================

set -u

LOG_FILE="${VPS_CLEANUP_LOG:-/var/log/vps-cleanup-daily.log}"
MAX_LOG_SIZE=${VPS_CLEANUP_MAX_LOG_BYTES:-5242880}     # 5MB rotate threshold
SWAP_RESET_MB=${VPS_CLEANUP_SWAP_RESET_MB:-500}
ZOMBIE_PARENT_ALLOWLIST="${ZOMBIE_PARENT_ALLOWLIST:-chrome chromium chrome-headless headless_shell timeout}"

# Rotate own log
if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)" -gt "$MAX_LOG_SIZE" ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

log "========== VPS CLEANUP STARTED =========="
log "Disk before: $(df -h / | awk 'NR==2{print $4}') free"
log "RAM  before: $(free -h | awk '/Mem/{print $4}') free | Swap: $(free -h | awk '/Swap/{print $3}') used"

# ============================
# 1. RAM
# ============================
log "--- RAM ---"
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
log "Page cache dropped"

SWAP_USED_MB=$(free -m | awk '/Swap/{print $3}')
if [ "${SWAP_USED_MB:-0}" -gt "$SWAP_RESET_MB" ] 2>/dev/null; then
    swapoff -a && swapon -a 2>/dev/null
    log "Swap reset (was ${SWAP_USED_MB}MB)"
fi

# ============================
# 2. ZOMBIES (allowlist only)
# ============================
log "--- ZOMBIES ---"
ZOMBIE_COUNT=$(ps aux | awk '$8=="Z"' | wc -l)
if [ "$ZOMBIE_COUNT" -gt 0 ]; then
    # First nudge: ask each parent to reap via SIGCHLD (harmless)
    for parent in $(ps -eo ppid,stat | awk '$2~/Z/{print $1}' | sort -u); do
        kill -s SIGCHLD "$parent" 2>/dev/null
    done
    sleep 2

    # Force-kill only allowlisted parents
    for parent in $(ps -eo ppid,stat | awk '$2~/Z/{print $1}' | sort -u); do
        pname=$(ps -p "$parent" -o comm= 2>/dev/null)
        for allowed in $ZOMBIE_PARENT_ALLOWLIST; do
            if [ "$pname" = "$allowed" ]; then
                kill -9 "$parent" 2>/dev/null
                log "Killed zombie parent: $parent ($pname)"
                break
            fi
        done
    done
    sleep 1
    NEW_COUNT=$(ps aux | awk '$8=="Z"' | wc -l)
    log "Zombies: $ZOMBIE_COUNT -> $NEW_COUNT"
fi

# ============================
# 3. DOCKER
# ============================
log "--- DOCKER ---"
if command -v docker >/dev/null 2>&1; then
    CLEANED=$(docker builder prune -af 2>&1 | grep -i "total" || echo "0B")
    log "Build cache: $CLEANED"

    IMG_CLEANED=$(docker image prune -f 2>&1 | grep -i "total" || echo "0B")
    log "Dangling images: $IMG_CLEANED"

    VOL_CLEANED=$(docker volume prune -f 2>&1 | grep -i "total" || echo "0B")
    log "Orphan volumes: $VOL_CLEANED"

    docker network prune -f >/dev/null 2>&1

    STOPPED=$(docker ps -aq --filter "status=exited" | wc -l)
    if [ "$STOPPED" -gt 0 ]; then
        log "Stopped containers: $STOPPED (kept)"
    fi
else
    log "docker not installed, skipping"
fi

# ============================
# 4. KUBERNETES (K3s)
# ============================
log "--- KUBERNETES ---"
if command -v kubectl >/dev/null 2>&1; then
    for status in Failed Succeeded; do
        PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=$status -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' 2>/dev/null)
        if [ -n "$PODS" ]; then
            echo "$PODS" | while read -r ns pod; do
                kubectl delete pod -n "$ns" "$pod" --grace-period=0 2>/dev/null
                log "Pod removed: $ns/$pod ($status)"
            done
        fi
    done

    command -v crictl >/dev/null 2>&1 && crictl rmi --prune 2>/dev/null && log "containerd images pruned"

    find /var/log/pods -name "*.log" -mtime +3 -delete 2>/dev/null
    find /var/lib/rancher/k3s/agent/containerd -name "*.log" -mtime +3 -delete 2>/dev/null
else
    log "kubectl not installed, skipping"
fi

# ============================
# 5. SYSTEM
# ============================
log "--- SYSTEM ---"
journalctl --vacuum-size=200M --vacuum-time=3d >/dev/null 2>&1
log "journald compacted"

find /tmp -type f -atime +2 -delete 2>/dev/null
find /var/tmp -type f -atime +5 -delete 2>/dev/null
log "temp files cleaned"

command -v apt-get >/dev/null 2>&1 && apt-get clean -y >/dev/null 2>&1

find /var/log/nginx -name "*.log.*.gz" -mtime +14 -delete 2>/dev/null

# Truncate own log if past 100MB
for logfile in "$LOG_FILE" /var/log/k3s-cleanup.log /var/log/docker-cleanup.log; do
    if [ -f "$logfile" ] && [ "$(stat -c%s "$logfile" 2>/dev/null || echo 0)" -gt 104857600 ]; then
        tail -1000 "$logfile" > "${logfile}.tmp" && mv "${logfile}.tmp" "$logfile"
        log "Log truncated: $logfile"
    fi
done

find /root/.cache -type f -atime +3 -delete 2>/dev/null
find /root/.npm/_cacache -type f -atime +7 -delete 2>/dev/null

# ============================
# RESULT
# ============================
log "Disk after: $(df -h / | awk 'NR==2{print $4}') free"
log "RAM  after: $(free -h | awk '/Mem/{print $4}') free | Swap: $(free -h | awk '/Swap/{print $3}') used"
log "========== VPS CLEANUP FINISHED =========="
log ""
