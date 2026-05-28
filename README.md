<p align="center">
  <a href="#-portugu%C3%AAs"><img src="https://img.shields.io/badge/-PT--BR-39d353?style=for-the-badge&labelColor=0d1117" alt="PT-BR"/></a>
  &nbsp;
  <a href="#-english"><img src="https://img.shields.io/badge/-EN-58a6ff?style=for-the-badge&labelColor=0d1117" alt="EN"/></a>
</p>

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=slice&color=0:0d1117,100:39d353&height=180&section=header&text=linux-vps-cleanup-daily&fontSize=34&fontColor=ffffff&animation=fadeIn&fontAlignY=42&desc=daily%20cleanup%20pra%20VPS%20Linux%20%C2%B7%20RAM%20%C2%B7%20docker%20%C2%B7%20k8s%20%C2%B7%20logs&descAlignY=68&descSize=14" width="100%" />
</p>

<p align="center">
  <img src="https://readme-typing-svg.demolab.com/?lines=%24+matheus%40devops%3A~%24+linux-vps-cleanup-daily;%24+RAM%2C+docker%2C+k8s%2C+zombie%2C+logs;%24+%7E160+linhas+de+bash%2C+sem+depend%C3%AAncia;%24+nunca+encosta+em+workload+ativo&font=Fira%20Code&size=18&pause=1200&color=39D353&center=true&vCenter=true&width=720&height=45" />
</p>

<a id="-português"></a>

## PT-BR

```bash
matheus@devops:~$ cat sobre.txt
```

Cleanup diário em 4 áreas pra uma VPS Linux que roda Docker e/ou K3s. Libera RAM, storage do Docker, pods mortos do Kubernetes, processos zumbi e logs/temp antigos — em ~160 linhas de bash puro, sem dependência além do que você já tem instalado.

- Cron-friendly, single file, sem dep externa
- Log próprio rotacionado em 5 MB; loga delta de espaço livre / RAM antes e depois
- **Zombie reaper conservador** — só dá SIGKILL em parents cujo `comm` esteja em allowlist (default: variantes do chrome + `timeout` do GNU)

```bash
matheus@devops:~$ ls stack/
```

![Bash](https://img.shields.io/badge/-Bash-0d1117?style=for-the-badge&logo=gnubash&logoColor=39d353) ![Linux](https://img.shields.io/badge/-Linux-0d1117?style=for-the-badge&logo=linux&logoColor=39d353) ![Docker](https://img.shields.io/badge/-Docker-0d1117?style=for-the-badge&logo=docker&logoColor=39d353) ![K3s](https://img.shields.io/badge/-K3s-0d1117?style=for-the-badge&logo=k3s&logoColor=39d353) ![systemd](https://img.shields.io/badge/-systemd-0d1117?style=for-the-badge&logo=systemd&logoColor=39d353) ![cron](https://img.shields.io/badge/-cron-0d1117?style=for-the-badge&logo=linux&logoColor=39d353)

```bash
matheus@devops:~$ cat o-que-faz.txt
```

| Passo | O quê | Notas |
|---|---|---|
| 1. RAM | `sync` + `echo 3 > /proc/sys/vm/drop_caches`; reseta swap se > 500 MB usado | Drop de page cache vira no-op quando o kernel não tem o que dropar |
| 2. Zumbis | Manda `SIGCHLD` pro parent de cada zumbi; depois `SIGKILL` só nos parents da allowlist | Allowlist default: `chrome chromium chrome-headless headless_shell timeout` |
| 3. Docker | `docker builder prune -af`, `docker image prune -f`, `docker volume prune -f`, `docker network prune -f` | Containers parados são **mantidos** (logados) |
| 4. Kubernetes | Deleta pods Failed/Succeeded; `crictl rmi --prune`; apaga log de pod > 3d | Só roda se `kubectl` estiver presente |
| 5. Sistema | `journalctl --vacuum-size=200M --vacuum-time=3d`; `/tmp`, `/var/tmp`, nginx logs antigos; `apt-get clean`; trunca log próprio > 100 MB | Pula `apt-get` se não tiver instalado |

```bash
matheus@devops:~$ ./install.sh
```

```bash
# 1. Copia
sudo cp vps-cleanup-daily.sh /usr/local/bin/vps-cleanup-daily.sh
sudo chmod +x /usr/local/bin/vps-cleanup-daily.sh

# 2. Cron — diariamente às 04:30
echo "30 4 * * * root /usr/local/bin/vps-cleanup-daily.sh" | sudo tee /etc/cron.d/vps-cleanup-daily

# 3. Acompanha o log
tail -f /var/log/vps-cleanup-daily.log
```

```bash
matheus@devops:~$ cat config.env
```

Tudo opcional. Defaults mostrados.

| Variável | Default | Pra quê |
|---|---|---|
| `VPS_CLEANUP_LOG` | `/var/log/vps-cleanup-daily.log` | Caminho do log |
| `VPS_CLEANUP_MAX_LOG_BYTES` | `5242880` (5 MB) | Threshold de rotação |
| `VPS_CLEANUP_SWAP_RESET_MB` | `500` | Reseta swap se uso > esse valor |
| `ZOMBIE_PARENT_ALLOWLIST` | `chrome chromium chrome-headless headless_shell timeout` | Nomes `comm` separados por espaço cujos parents zumbi podem levar SIGKILL |

```bash
matheus@devops:~$ cat seguranca.txt
```

- O zombie reaper é **estritamente opt-in**. Se você não adicionar o nome do processo em `ZOMBIE_PARENT_ALLOWLIST`, ele nunca vai ser morto por esse script.
- Os prunes do Docker nunca tocam em imagens em uso por container rodando.
- A seção K8s só deleta pods nas fases `Failed` ou `Succeeded`.
- A seção de sistema usa `find -atime` (access time), não `mtime`, então arquivo que você acabou de ler não vai ser deletado mesmo que seja antigo.

```bash
matheus@devops:~$ which deps
```

Hard requirements: `bash`, `awk`, `find`, `stat`, `ps`, `kill`, `du`, `df`, `free`, `sync`, `journalctl`.

Soft (pulado se não tiver): `docker`, `kubectl`, `crictl`, `jq`, `apt-get`.

```bash
matheus@devops:~$ cat LICENSE
```

MIT — veja [LICENSE](LICENSE).

```bash
matheus@devops:~$ contact
```

[![LinkedIn](https://img.shields.io/badge/-LinkedIn-0d1117?style=for-the-badge&logo=linkedin&logoColor=39d353)](https://www.linkedin.com/in/matheus-henrique-prates-586328234/)
[![Email](https://img.shields.io/badge/-Email-0d1117?style=for-the-badge&logo=gmail&logoColor=39d353)](mailto:mathues12398henrique@gmail.com)

```bash
matheus@devops:~$ _
```

---

<a id="-english"></a>

## EN

```bash
matheus@devops:~$ cat about.txt
```

Daily 4-area cleanup for a Linux VPS that runs Docker and/or K3s. Reclaims RAM, Docker storage, dead Kubernetes pods, zombie processes, and old logs/temp files — in ~160 lines of plain bash with no dependencies beyond the tools you'd already have.

- Cron-friendly, single file, no external deps
- Own log auto-rotated at 5 MB; emits free-space / RAM delta before and after
- **Conservative zombie reaper** — only SIGKILLs parents whose `comm` name appears in an allowlist (default: chrome variants + GNU `timeout`)

```bash
matheus@devops:~$ ls stack/
```

![Bash](https://img.shields.io/badge/-Bash-0d1117?style=for-the-badge&logo=gnubash&logoColor=39d353) ![Linux](https://img.shields.io/badge/-Linux-0d1117?style=for-the-badge&logo=linux&logoColor=39d353) ![Docker](https://img.shields.io/badge/-Docker-0d1117?style=for-the-badge&logo=docker&logoColor=39d353) ![K3s](https://img.shields.io/badge/-K3s-0d1117?style=for-the-badge&logo=k3s&logoColor=39d353) ![systemd](https://img.shields.io/badge/-systemd-0d1117?style=for-the-badge&logo=systemd&logoColor=39d353) ![cron](https://img.shields.io/badge/-cron-0d1117?style=for-the-badge&logo=linux&logoColor=39d353)

```bash
matheus@devops:~$ cat what-it-does.txt
```

| Step | What | Notes |
|---|---|---|
| 1. RAM | `sync` + `echo 3 > /proc/sys/vm/drop_caches`; resets swap if > 500 MB used | Page cache drop is a no-op when the kernel doesn't have anything to drop |
| 2. Zombies | Sends `SIGCHLD` to each zombie's parent; then `SIGKILL`s only allowlisted parents | Default allowlist: `chrome chromium chrome-headless headless_shell timeout` |
| 3. Docker | `docker builder prune -af`, `docker image prune -f`, `docker volume prune -f`, `docker network prune -f` | Stopped containers are **kept** (logged) |
| 4. Kubernetes | Deletes Failed/Succeeded pods; `crictl rmi --prune`; deletes pod logs > 3d | Only runs if `kubectl` is present |
| 5. System | `journalctl --vacuum-size=200M --vacuum-time=3d`; old `/tmp`, `/var/tmp`, nginx logs; `apt-get clean`; truncate own log > 100 MB | Skips `apt-get` if not installed |

```bash
matheus@devops:~$ ./install.sh
```

```bash
# 1. Copy
sudo cp vps-cleanup-daily.sh /usr/local/bin/vps-cleanup-daily.sh
sudo chmod +x /usr/local/bin/vps-cleanup-daily.sh

# 2. Cron — daily at 04:30
echo "30 4 * * * root /usr/local/bin/vps-cleanup-daily.sh" | sudo tee /etc/cron.d/vps-cleanup-daily

# 3. Watch the log
tail -f /var/log/vps-cleanup-daily.log
```

```bash
matheus@devops:~$ cat config.env
```

All optional. Defaults shown.

| Variable | Default | Purpose |
|---|---|---|
| `VPS_CLEANUP_LOG` | `/var/log/vps-cleanup-daily.log` | Log file path |
| `VPS_CLEANUP_MAX_LOG_BYTES` | `5242880` (5 MB) | Rotation threshold |
| `VPS_CLEANUP_SWAP_RESET_MB` | `500` | Reset swap if used > this |
| `ZOMBIE_PARENT_ALLOWLIST` | `chrome chromium chrome-headless headless_shell timeout` | Space-separated `comm` names whose zombie parents may be SIGKILL'd |

```bash
matheus@devops:~$ cat safety.txt
```

- The zombie reaper is **strictly opt-in**. If you don't add a process name to `ZOMBIE_PARENT_ALLOWLIST`, it'll never be killed by this script.
- Docker prunes never touch images currently used by a running container.
- The K8s section only deletes pods in `Failed` or `Succeeded` phases.
- The system section uses `find -atime` (access time), not `mtime`, so a file you've recently read won't be deleted even if it's old.

```bash
matheus@devops:~$ which deps
```

Hard requirements: `bash`, `awk`, `find`, `stat`, `ps`, `kill`, `du`, `df`, `free`, `sync`, `journalctl`.

Soft (skipped if missing): `docker`, `kubectl`, `crictl`, `jq`, `apt-get`.

```bash
matheus@devops:~$ cat LICENSE
```

MIT — see [LICENSE](LICENSE).

```bash
matheus@devops:~$ contact
```

[![LinkedIn](https://img.shields.io/badge/-LinkedIn-0d1117?style=for-the-badge&logo=linkedin&logoColor=39d353)](https://www.linkedin.com/in/matheus-henrique-prates-586328234/) [![Email](https://img.shields.io/badge/-Email-0d1117?style=for-the-badge&logo=gmail&logoColor=39d353)](mailto:mathues12398henrique@gmail.com)

```bash
matheus@devops:~$ _
```

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:39d353,100:0d1117&height=120&section=footer" width="100%" />
</p>
