# Final demonstration – the 11 steps (PDF §8), command by command

**Before the evaluator arrives (about 10 min)**
- Both laptops on the same network. Run `./scripts/network-info.sh` and check the IPs still match `team.env`.
  If not: edit, `./scripts/render.sh`, and restart the services.
- **L2 tabs:** Backend A · Backend B · `./scripts/start-edge.sh primary` then `./scripts/edge-logs.sh`
- **L1 tabs:** `./scripts/start-dns.sh primary` (leave the query log visible) · a working tab
- Run `./scripts/verify.sh` on L1. It must say PHASE 1 GATE PASSED.
- Open in advance: the Wireshark capture `evidence/pcap/full-flow-*.pcap`, `docs/ARCHITECTURE.md`, and the browser tab.
- Decide who speaks for which step, but **both** of you must be ready to answer anything.

| # | Step | Who / where | Commands / actions | What to say |
|---|---|---|---|---|
| 1 | Topology + IP/service inventory | either | open `docs/ARCHITECTURE.md` | "Two laptops on one subnet. L1 is DNS and client; L2 is edge plus two backends. The request flow is…" |
| 2 | All machines on the private LAN | each on own laptop | `./scripts/network-info.sh` then `./scripts/ping-all.sh` | "Same /24, same gateway. ICMP proves layer-3 reachability." |
| 3 | Resolve the private domain | L1 | `dig app.team1.test` (point at the ANSWER section and `SERVER: <L1-IP>#53`) | "Our dnsmasq answered. The A record points to the **edge**, TTL 30." Show the query in the DNS tab. |
| 4 | Open the service over HTTPS by name | L1 | browser → `https://app.team1.test/api/status` (padlock, click it → certificate issued by our CA). Then `curl https://app.team1.test/api/status --cacert certs/ca.crt` | "No IP in the URL, no warning. The cert is signed by our CA, which is trusted on this Mac." |
| 5 | Load balancing | L1 | `./scripts/test-lb.sh 8` | "Round robin: A, B, A, B. The client always talks to the same name and IP." Point at the `upstream=` column in L2's edge log. |
| 6 | Wireshark: DNS, TCP, TLS | L1 | open the saved pcap. Filters: `dns`, `tcp.flags.syn==1`, `tls.handshake` | query/response + TTL · SYN/SYN-ACK/ACK with ports · ClientHello (SNI), ServerHello, Certificate (TLS 1.2 stream), ChangeCipherSpec, then Application Data (encrypted). |
| 7 | HTTP headers + caching | L1 | `./scripts/test-cache.sh`. Optionally, browser DevTools → Network → reload `/api/data` → "(disk cache)" | "max-age=60 means a fresh hit without asking. ETag + If-None-Match gives a 304 with no body." |
| 8 | Fail one backend | L2: Ctrl+C Backend A. L1: `./scripts/test-lb.sh 6` | | "All B, zero errors. nginx retried and marked A down for 10 s." Restart A, run test-lb again: A is back. |
| 9 | Phase 2 DNS / resilience | L2: `./scripts/start-dns.sh backup` (should already be running). L1: Ctrl+C the primary DNS, `./scripts/flush-dns.sh`, `dig app.team1.test`, `curl …` | | "Primary is down, the backup answers, the service continues." Optionally also TTL (`watch-dns.sh` + `dns-point-app.sh`) or the edge cutover (Ext E). |
| 10 | Faculty-injected fault | both | follow the layer ladder below | Say each layer out loud. |
| 11 | Individual viva | each | – | [02-CONCEPTS.md](02-CONCEPTS.md) §11 |

---

## F. The troubleshooting ladder (step 10) – memorise this

```
0  ping <edge IP>                         -> LAN ok?
1  dig app.team1.test                     -> name resolves? from WHICH server? (SERVER: line)
2  …answer == edge IP in team.env?        -> record ok?
3  nc -vz app.team1.test 443              -> TCP port open? (refused vs timeout)
4  curl -v https://app.team1.test 2>&1 | grep -iE 'SSL|certificate|subject|expire'
                                          -> TLS ok?
5  curl -i https://app.team1.test/api/status   -> HTTP status? 502 => backends
6  (on L2) curl -i http://<backend IP>:3001/api/status ; tail run/logs/edge-primary-error.log
```

### Practice faults (one person breaks something, the other diagnoses it)

| Fault to inject | Where | Symptom → layer |
|---|---|---|
| Ctrl+C dnsmasq (backup stopped too) | L1 | `dig` times out → DNS |
| `./scripts/dns-point-app.sh 192.168.1.250` + flush | L1 | dig OK but wrong IP, curl times out → DNS record |
| `sudo networksetup -setdnsservers Wi-Fi 8.8.8.8` | client | `dig @L1` OK, `dig` (default) NXDOMAIN → client resolver |
| `./scripts/stop-edge.sh` | L2 | ping OK, `nc -vz :443` refused → TCP / edge |
| Edit `build/nginx/edge-primary.conf`, set 3001→3009, `./scripts/start-edge.sh primary` | L2 | half the requests are slow/retried, logs show the upstream connect error → proxy config |
| Stop both backends | L2 | TLS OK, HTTP 502 → application |
| Rename `certs/server.crt`, restart nginx | L2 | nginx won't start → config test shows the cert path |
| `./scripts/firewall-on.sh` with the wrong EDGE_IP | L2 | 502/timeouts → firewall |
| Wrong port in the URL (`:8443`) | client | refused → transport |

After each one, put it back (`./scripts/render.sh` regenerates every config cleanly).
