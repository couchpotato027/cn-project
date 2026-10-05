# Final demonstration – the 11 steps (PDF §8), command by command

**Before the evaluator arrives (about 10 min)**
- All 3 laptops on the same network, `caffeinate -dims` running on each. Run `./scripts/network-info.sh` and check the IPs still match `team.env`.
  If not: edit, `./scripts/render.sh`, and restart the services.
- **L3 (Nishant) tabs:** Backend A · `./scripts/start-dns.sh backup`
- **L2 (Bhavay) tabs:** Backend B · `./scripts/start-edge.sh primary` then `./scripts/edge-logs.sh`
- **L1 (Priyansh) tabs:** `./scripts/start-dns.sh primary` (leave the query log visible) · a working tab
- Run `./scripts/verify.sh` on L1. It must say PHASE 1 GATE PASSED.
- Open in advance: the Wireshark capture `evidence/pcap/full-flow-*.pcap`, `docs/ARCHITECTURE.md`, and the browser tab.
- Suggested speakers: Priyansh steps 1–3 and 6, Bhavay steps 4–5 and 8, Nishant steps 7 and 9. **All three** of you must be ready to answer anything.

| # | Step | Who / where | Commands / actions | What to say |
|---|---|---|---|---|
| 1 | Topology + IP/service inventory | either | open `docs/ARCHITECTURE.md` | "Three laptops on one subnet. L1 is DNS and client; L2 is the edge plus Backend B; L3 is Backend A plus the backup DNS. The request flow is…" |
| 2 | All machines on the private LAN | each on own laptop | `./scripts/network-info.sh` then `./scripts/ping-all.sh` | "Same /24, same gateway. ICMP proves layer-3 reachability." |
| 3 | Resolve the private domain | L1 | `dig app.team67.test` (point at the ANSWER section and `SERVER: <L1-IP>#53`) | "Our dnsmasq answered. The A record points to the **edge**, TTL 30." Show the query in the DNS tab. |
| 4 | Open the service over HTTPS by name | L1 | browser → `https://app.team67.test/api/status` (padlock, click it → certificate issued by our CA). Then `curl https://app.team67.test/api/status --cacert certs/ca.crt` | "No IP in the URL, no warning. The cert is signed by our CA, which is trusted on this Mac." |
| 5 | Load balancing | L1 | `./scripts/test-lb.sh 8` | "Round robin: A, B, A, B. The client always talks to the same name and IP." Point at the `upstream=` column in L2's edge log. |
| 6 | Wireshark: DNS, TCP, TLS | L1 | open the saved pcap. Filters: `dns`, `tcp.flags.syn==1`, `tls.handshake` | query/response + TTL · SYN/SYN-ACK/ACK with ports · ClientHello (SNI), ServerHello, Certificate (TLS 1.2 stream), ChangeCipherSpec, then Application Data (encrypted). |
| 7 | HTTP headers + caching | L1 | `./scripts/test-cache.sh`. Optionally, browser DevTools → Network → reload `/api/data` → "(disk cache)" | "max-age=60 means a fresh hit without asking. ETag + If-None-Match gives a 304 with no body." |
| 8 | Fail one backend | L3: Ctrl+C Backend A (or close the lid). L1: `./scripts/test-lb.sh 6` | | "All B, zero errors. nginx retried and marked A down for 10 s." Restart A, run test-lb again: A is back. |
| 9 | Phase 2 DNS / resilience | L3: `./scripts/start-dns.sh backup` (should already be running). L1: Ctrl+C the primary DNS, `./scripts/flush-dns.sh`, `dig app.team67.test`, `curl …` | | "Primary is down, the backup answers, the service continues." Optionally also TTL (`watch-dns.sh` + `dns-point-app.sh`) or the edge cutover (Ext E). |
| 10 | Faculty-injected fault | all three | follow the layer ladder below | Say each layer out loud. |
| 11 | Individual viva | each | – | [02-CONCEPTS.md](02-CONCEPTS.md) §11 |

---

## F. The troubleshooting ladder (step 10) – memorise this

```
0  ping <edge IP>                         -> LAN ok?
1  dig app.team67.test                     -> name resolves? from WHICH server? (SERVER: line)
2  …answer == edge IP in team.env?        -> record ok?
3  nc -vz app.team67.test 443              -> TCP port open? (refused vs timeout)
4  curl -v https://app.team67.test 2>&1 | grep -iE 'SSL|certificate|subject|expire'
                                          -> TLS ok?
5  curl -i https://app.team67.test/api/status   -> HTTP status? 502 => backends
6  (on L2) curl -i http://<L3-IP>:3001/api/status ; tail run/logs/edge-primary-error.log
```

### Practice faults (one person breaks something, the other two diagnose it)

| Fault to inject | Where | Symptom → layer |
|---|---|---|
| Ctrl+C dnsmasq (backup stopped too) | L1 | `dig` times out → DNS |
| `./scripts/dns-point-app.sh <L3-IP>` + flush | L1 | dig OK but wrong IP, curl refused → DNS record |
| `sudo networksetup -setdnsservers Wi-Fi 8.8.8.8` | client | `dig @L1` OK, `dig` (default) NXDOMAIN → client resolver |
| `./scripts/stop-edge.sh` | L2 | ping OK, `nc -vz :443` refused → TCP / edge |
| Edit `build/nginx/edge-primary.conf`, set 3001→3009, `./scripts/start-edge.sh primary` | L2 | only B answers, error log shows the upstream connect error → proxy config |
| Stop both backends | L2 + L3 | TLS OK, HTTP 502 → application |
| Rename `certs/server.crt`, restart nginx | L2 | nginx won't start → config test shows the cert path |
| `./scripts/firewall-on.sh` with the wrong EDGE_IP | L3 | only B answers, A times out from the edge → firewall |
| Wrong port in the URL (`:8443`) | client | refused → transport |

After each one, put it back (`./scripts/render.sh` regenerates every config cleanly).
