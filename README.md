# linux-vps-cleanup-daily

Daily 4-area cleanup for a Linux VPS that runs Docker and/or K3s. Reclaims
RAM, Docker storage, dead Kubernetes pods, zombie processes, and old
logs/temp files — in ~160 lines of plain bash with no dependencies beyond
the tools you'd already have.

- Cron-friendly, single file, no external deps
- Own log auto-rotated at 5 MB; emits free-space / RAM delta before and after
- **Conservative zombie reaper** — only SIGKILLs parents whose `comm` name
  appears in an allowlist (default: chrome variants + GNU `timeout`)

## What it does

| Step | What | Notes |
|---|---|---|
| 1. RAM | `sync` + `echo 3 > /proc/sys/vm/drop_caches`; resets swap if > 500 MB used | Page cache drop is a no-op when the kernel doesn't have anything to drop |
| 2. Zombies | Sends `SIGCHLD` to each zombie's parent; then `SIGKILL`s only allowlisted parents | Default allowlist: `chrome chromium chrome-headless headless_shell timeout` |
| 3. Docker | `docker builder prune -af`, `docker image prune -f`, `docker volume prune -f`, `docker network prune -f` | Stopped containers are **kept** (logged) |
| 4. Kubernetes | Deletes Failed/Succeeded pods; `crictl rmi --prune`; deletes pod logs > 3d | Only runs if `kubectl` is present |
| 5. System | `journalctl --vacuum-size=200M --vacuum-time=3d`; old `/tmp`, `/var/tmp`, nginx logs; `apt-get clean`; truncate own log > 100 MB | Skips `apt-get` if not installed |

## Install

```bash
# 1. Copy
sudo cp vps-cleanup-daily.sh /usr/local/bin/vps-cleanup-daily.sh
sudo chmod +x /usr/local/bin/vps-cleanup-daily.sh

# 2. Cron — daily at 04:30
echo "30 4 * * * root /usr/local/bin/vps-cleanup-daily.sh" | sudo tee /etc/cron.d/vps-cleanup-daily

# 3. Watch the log
tail -f /var/log/vps-cleanup-daily.log
```

## Configuration

All optional. Defaults shown.

| Variable | Default | Purpose |
|---|---|---|
| `VPS_CLEANUP_LOG` | `/var/log/vps-cleanup-daily.log` | Log file path |
| `VPS_CLEANUP_MAX_LOG_BYTES` | `5242880` (5 MB) | Rotation threshold |
| `VPS_CLEANUP_SWAP_RESET_MB` | `500` | Reset swap if used > this |
| `ZOMBIE_PARENT_ALLOWLIST` | `chrome chromium chrome-headless headless_shell timeout` | Space-separated `comm` names whose zombie parents may be SIGKILL'd |

## Safety

- The zombie reaper is **strictly opt-in**. If you don't add a process name
  to `ZOMBIE_PARENT_ALLOWLIST`, it'll never be killed by this script.
- Docker prunes never touch images currently used by a running container.
- The K8s section only deletes pods in `Failed` or `Succeeded` phases.
- The system section uses `find -atime` (access time), not `mtime`, so a file
  you've recently read won't be deleted even if it's old.

## Requirements

Hard requirements: `bash`, `awk`, `find`, `stat`, `ps`, `kill`, `du`, `df`,
`free`, `sync`, `journalctl`.

Soft (skipped if missing): `docker`, `kubectl`, `crictl`, `jq`, `apt-get`.

## License

MIT — see [LICENSE](LICENSE).
