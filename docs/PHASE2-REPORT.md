# Phase 2 Final Report – Team 67 (Priyansh Satija, Bhavay Goyal, Nishant Sharma)

Section B · Type 2 (3 Macs, combined roles) · Domain `app.team67.test` · all runs on 2026-11-23/24 (IST)

| Laptop | Member | IP (Phase 2 session) | Roles |
|---|---|---|---|
| L1 | Priyansh | 10.7.26.79 | primary DNS, test client |
| L2 | Bhavay | 10.7.13.123 | primary nginx edge, Backend B :3002 |
| L3 | Nishant | 10.7.19.207 | Backend A :3001, backup DNS, standby edge |

(The IPs differ from Phase 1 because the college DHCP assigned new addresses. All configs are generated from
`team.env`, so changing three lines and running `./scripts/render.sh` re-pointed every service.)

All evidence files referred to below are in [`evidence/phase2/`](../evidence/phase2/).

## 1. What changed from Phase 1

- **Backup DNS resolver** on Laptop 3 with the same records; every client lists primary + backup.
- **DNS TTL 30 s** (`local-ttl=30`), records in a hosts file reloadable with SIGHUP, so a record can be changed live.
- **pf firewall rules** (own anchor `com.apple/cnproject`) on both backend machines: only the edge IP may reach 3001/3002.
- **nginx passive health checks** (`max_fails=1 fail_timeout=10s`) + retry on the other backend (`proxy_next_upstream`).
- **Standby nginx edge** on Laptop 3 with the same config and certificate, for a DNS-based cutover.

## 2. Resilience tests and results

| Test | Expected | Observed | Evidence |
|---|---|---|---|
| Both DNS servers up | both answer the same record | primary `10.7.26.79` and backup `10.7.19.207` both answer `app.team67.test A 10.7.13.123`, TTL 30 | `extA-A2-both-dns-answering.txt` |
| **Ext A** – primary DNS stopped | names still resolve via backup | `dig` after stopping the primary: `SERVER: 10.7.19.207`, `HTTP 200` by name | `extA-backup-dns-failover.txt`, `extA-A1-…webp` |
| **Ext B** – record changed (TTL 30) | server changes at once, client cache keeps old IP until TTL | changed 23:42:45: server answered the new IP the same second; OS resolver kept the old IP for 29 s, switched at 23:43:14 | `extB-ttl-timeline.txt` |
| **Ext B** – manual flush | new IP immediately | server back at 23:44:04, OS resolver followed at 23:44:06 after `flush-dns.sh` (2 s instead of 29 s) | `extB-flush-timeline.txt` |
| **Ext C** – direct access to :3001/:3002 from the client, firewall ON | blocked | both `TCP connect timed out - SYN dropped by pf` | `extC-2-isolation.txt` |
| **Ext C** – access through the edge, firewall ON | still works | `https://app.team67.test/api/status -> 200 via the edge` | `extC-2-isolation.txt` |
| **Ext C** – before / rollback | direct access works before and after | before: both HTTP 200; after `firewall-off.sh`: both HTTP 200 again | `extC-1-before.txt`, `extC-3-rollback-check.txt`, `extC-C1-…webp` |
| **Ext D** – Backend A stopped under load | 0 failed requests, all served by B | 40 requests/1 s: A/B alternating, then after A was stopped every request HTTP 200 from B, failed: 0; after restart A rejoined (`A B A B…`, failed: 0) | `extD-failover.txt` |
| **Ext E** – standby edge reachable | answers by name | `x-edge: standby (10.7.19.207)`, HTTP/2 200 | `extE-1-standby-edge.txt` |
| **Ext E** – DNS cutover to the standby | cached clients stay on old edge up to TTL, then move | cutover 00:44:41: requests #1–#35 still `primary` (cached answer), #36–#55 `standby`, 0 failed; after switching back, `primary` again | `extE-cutover.txt` |
| **Ext F** – fault injected | find the layer systematically | ping, DNS, TCP 443, TLS/HTTP all fine, a single HTTP 200 hid the fault; checking `X-Backend` showed Backend B down; fixed, gate passed | `extF-troubleshooting.txt` |

### Things that did not go to plan (and what they taught us)
- **Ext D first attempt:** 17 requests failed from the client for an unexplained, self-healing connectivity glitch and Backend A was
  not stopped during that run. We discarded it (`extD-attempt1-…NOT-failover.txt`) and repeated the test properly.
- **Ext E first attempt:** the DNS change was never made during the run, so every request stayed on the primary edge
  (`extE-attempt1-no-cutover-happened.txt`). The repeat used a timed script.
- **Laptops sleeping:** twice a laptop went to sleep (ping replied with `ttl=32` and ~600 ms because the access point answered for the
  sleeping Mac, while every TCP port timed out). We diagnosed it by layer and now keep `caffeinate -dims` running.
- **Stray DNS processes:** a leftover dnsmasq kept answering after Ctrl+C in the wrong tab; we found the exact PID with `ps` and stopped it,
  then re-ran the Ext A proof so the backup server (`SERVER: 10.7.19.207`) was shown answering alone.

## 3. Troubleshooting findings (Extension F)

**Fault injected (by Bhavay): Backend B stopped.** Method – bottom-up, one layer at a time:

1. `ping -c 2 10.7.13.123` – 0% loss, ttl=64 → network OK.
2. `dig +short app.team67.test` – `10.7.13.123` → DNS OK.
3. `nc -vz app.team67.test 443` – succeeded → nginx listening, TCP OK.
4. `curl -sv https://app.team67.test/api/status` – TLSv1.3, `SSL certificate verify ok`, `HTTP/2 200` → TLS and HTTP OK.
5. Direct test of each backend + `X-Backend` over 6 requests – B did not answer, all 6 replies came from A → **application layer: Backend B down**.

Lesson: a healthy-looking 200 can hide a failed backend because nginx absorbs the failure; always check which backend answered.
Fix: `./scripts/start-backend.sh B`; `./scripts/verify.sh` → `sequence of backends: ABABAB`, PHASE 1 GATE PASSED.

## 4. Learning summary

**A – Backup DNS:** A client is configured with two resolvers; it asks the first and falls back to the second after a timeout, so a DNS outage
costs a short delay instead of a failure. Both servers must serve identical records. This differs from an application failure: with DNS down
the name cannot be resolved at all, with a backend down the name resolves and TCP/TLS to the edge work (and nginx hides or reports the failure).

**B – TTL and record change:** Every DNS answer carries a TTL; resolvers and the OS cache it. After we changed the record the server answered the
new IP immediately, but the Mac kept the old one for 29 s (TTL 30). A manual flush removes the cache at once. In production you lower the TTL
before a migration so traffic moves quickly. A record change must be applied on every DNS server, otherwise a client falling back to the other
server would still receive the old address.

**C – Service isolation:** pf is a stateful packet filter. Our rules (own anchor, so the system firewall is untouched, rolled back with one
command) allow only the edge IP to open connections to 3001/3002 and silently drop everything else, so a direct client sees a connect
timeout while the service through the edge keeps working. Principle: least privilege / defence in depth; cloud equivalent: security groups.

**D – High-availability failover:** `max_fails=1 fail_timeout=10s` plus `proxy_next_upstream error timeout` makes nginx retry a failed request on
the other backend and skip the dead one for 10 s; clients saw zero failed requests. When Backend A came back it rejoined after the timeout.
The single point of failure that remains is the edge nginx on Laptop 2, which also hosts Backend B. Removing it needs a second edge with a
floating IP (VRRP/keepalived), DNS health checks with multiple edges, or a managed load balancer.

**E – Controlled edge migration:** A second nginx with the same configuration and certificate runs on Laptop 3. Changing the DNS record moves
new lookups to it, while clients holding the cached answer keep using the old edge until the TTL expires (we saw ~25 s of `primary` after the
change, then `standby`, with no failed request). This is DNS-based cutover; it is limited by TTL, which is why production migrations lower the TTL first.

**F – Troubleshooting:** Work bottom-up and say the layer out loud: network (ping), DNS (dig), transport (nc to the port), TLS/HTTP (curl -v),
then the backends. Refused means nothing listens; a timeout means something drops packets or the host is asleep. Evidence beats guessing.
