# Evidence folder (the evaluator must find anything within 30 seconds)

Scripts save into these folders automatically. Add screenshots by hand.

| Folder | Contents | Produced by |
|---|---|---|
| `taskA/` | IP/mask/gateway/interface/MAC per laptop, ping results | `network-info.sh`, `ping-all.sh` |
| `dns/` | dig / dscacheutil / nslookup output | `check-dns.sh` |
| `http/` | `curl -v` / `curl -I` output (headers, load balancing) | `curl -v … \| tee evidence/http/…` |
| `caching/` | 200 vs 304, Cache-Control, ETag | `test-cache.sh` |
| `pcap/` | Wireshark captures (DNS, TCP handshake, TLS) | `capture.sh` |
| `screenshots/` | Wireshark screenshots with the relevant packet selected, browser padlock, DevTools cache | by hand |
| `failures/` | each Phase 1 failure scenario: command + output/screenshot | by hand |
| `phase2/` | Ext A–F results | by hand / script output |

Name files by task, e.g. `screenshots/taskG-tls-handshake.png`, `failures/both-backends-502.png`.
