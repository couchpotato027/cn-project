# Evidence index – Team 67 (Phase 1)

Laptop 1 Priyansh `10.7.19.6` (DNS + client) · Laptop 2 Bhavay `10.7.27.44` (edge + Backend B) ·
Laptop 3 Nishant `10.7.23.55` (Backend A). Domain `app.team67.test`. All captured 2026-10-05.

**Gate:** [`phase1-gate-passed.jpeg`](phase1-gate-passed.jpeg) – `./scripts/verify.sh` → PHASE 1 GATE PASSED.

## Task A – Private LAN
| Requirement | File |
|---|---|
| IPv4, mask/prefix, gateway, interface, MAC of each Mac | [`taskA/Priyanshs-MacBook-Pro-2.txt`](taskA/Priyanshs-MacBook-Pro-2.txt), [`taskA/Bhavays-MacBook-Pro.txt`](taskA/Bhavays-MacBook-Pro.txt), [`taskA/Nishants-MacBook-Pro.txt`](taskA/Nishants-MacBook-Pro.txt) |
| Ping between every pair | [`taskA/ping-from-Priyanshs-MacBook-Pro-2.txt`](taskA/ping-from-Priyanshs-MacBook-Pro-2.txt), [`taskA/ping-from-Bhavays-MacBook-Pro.txt`](taskA/ping-from-Bhavays-MacBook-Pro.txt), [`taskA/ping-from-Nishants-MacBook-Pro.txt`](taskA/ping-from-Nishants-MacBook-Pro.txt), [`A-lan/A2-ping-and-roles-bhavay.jpeg`](A-lan/A2-ping-and-roles-bhavay.jpeg), [`A-lan/A2-ping-and-client-dns-nishant.jpeg`](A-lan/A2-ping-and-client-dns-nishant.jpeg) |
| Topology diagram | [`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) §1 |

## Task B – Private DNS
| Requirement | File |
|---|---|
| dnsmasq running, records loaded, queries logged | [`B-dns/B2-dns-server-running-priyansh.jpeg`](B-dns/B2-dns-server-running-priyansh.jpeg) |
| `dig` / `nslookup` / OS resolver from a client | [`B-dns/B1-check-dns-priyansh.jpeg`](B-dns/B1-check-dns-priyansh.jpeg), [`dns/dns-dns1-150220.txt`](dns/dns-dns1-150220.txt), [`B-dns/B4-dig-short-priyansh.jpeg`](B-dns/B4-dig-short-priyansh.jpeg) |
| At least two other Macs use Mac 1 as resolver | [`B-dns/B3-client-dns-trust-edge-bhavay.jpeg`](B-dns/B3-client-dns-trust-edge-bhavay.jpeg), [`B-dns/B3-client-dns-nishant.jpeg`](B-dns/B3-client-dns-nishant.jpeg) (+ [`B-dns/B3-client-dns-priyansh.jpeg`](B-dns/B3-client-dns-priyansh.jpeg)) |
| Config | [`../config-bundle/dnsmasq-primary.conf`](../config-bundle/dnsmasq-primary.conf), [`../config-bundle/records.hosts`](../config-bundle/records.hosts) |

## Task C – Two backends
| Requirement | File |
|---|---|
| Both backends answer on the LAN with `X-Backend` | [`C-backends/C1-direct-backends-from-priyansh.jpeg`](C-backends/C1-direct-backends-from-priyansh.jpeg) |
| Backends running (A on L3, B on L2), ports 3001/3002 | [`C-backends/C2-backend-B-running-bhavay.jpeg`](C-backends/C2-backend-B-running-bhavay.jpeg), [`C-backends/C3-backend-A-running-nishant.jpeg`](C-backends/C3-backend-A-running-nishant.jpeg) |
| Backend only sees the edge (`peer=10.7.27.44`, real client in `xff`) | [`C-backends/C4-backend-A-via-edge-nishant.jpeg`](C-backends/C4-backend-A-via-edge-nishant.jpeg) |
| Source code | [`../backend/server.py`](../backend/server.py) |

## Task D – Reverse proxy + load balancer
| Requirement | File |
|---|---|
| Repeated requests alternate A/B | [`D-loadbalancer/D1-round-robin.jpeg`](D-loadbalancer/D1-round-robin.jpeg) |
| Edge log: `upstream=` alternating, failover retries | [`D-loadbalancer/D2-edge-access-log-bhavay.jpeg`](D-loadbalancer/D2-edge-access-log-bhavay.jpeg) |
| Config | [`../config-bundle/edge-primary.conf`](../config-bundle/edge-primary.conf) |

## Task E – HTTPS / TLS
| Requirement | File |
|---|---|
| Browser over HTTPS by name, no warning | [`E-tls/E1-browser-https-backend-A.jpeg`](E-tls/E1-browser-https-backend-A.jpeg) |
| Certificate (subject, issuer = our CA, SAN, validity), `Verify return code: 0 (ok)` | [`E-tls/E2-certificate-openssl.jpeg`](E-tls/E2-certificate-openssl.jpeg), [`E-tls/E2-certificate.txt`](E-tls/E2-certificate.txt) |
| CA added to the trust store of every client Mac | Priyansh: [`E-tls/E3-ca-trusted-priyansh.jpeg`](E-tls/E3-ca-trusted-priyansh.jpeg) · Bhavay: [`B-dns/B3-client-dns-trust-edge-bhavay.jpeg`](B-dns/B3-client-dns-trust-edge-bhavay.jpeg) · Nishant: [`E-tls/E3-ca-before-and-after-trust-nishant.jpeg`](E-tls/E3-ca-before-and-after-trust-nishant.jpeg) |
| Validation is real: untrusted CA is rejected (`curl: (60)`, verify=20), then accepted after trust (verify=0) | [`E-tls/E3-ca-before-and-after-trust-nishant.jpeg`](E-tls/E3-ca-before-and-after-trust-nishant.jpeg) |
| TLS handshake steps + "certificate verify ok" without `-k` | [`E-tls/E4-curl-verbose-1-tls-handshake.jpeg`](E-tls/E4-curl-verbose-1-tls-handshake.jpeg), [`E-tls/E4-curl-verbose-2-cert-and-http.jpeg`](E-tls/E4-curl-verbose-2-cert-and-http.jpeg), [`http/curl-v.txt`](http/curl-v.txt) |
| Setup notes | [`../config-bundle/README.md`](../config-bundle/README.md) |

## Task F – HTTP caching
| Requirement | File |
|---|---|
| `Cache-Control: max-age=60` + `ETag`, conditional request → **304**, 496 vs 0 bytes | [`F-caching/F1-cache-headers-304.jpeg`](F-caching/F1-cache-headers-304.jpeg), [`caching/caching-150449.txt`](caching/caching-150449.txt) |
| Cacheable resource in the browser | [`F-caching/F0-browser-api-data.jpeg`](F-caching/F0-browser-api-data.jpeg) |

## Task G – Complete protocol flow (Wireshark)
| Layer / event | File |
|---|---|
| Capture run (DNS + TLS 1.2 + TLS 1.3 requests) | [`G-wireshark/G0-capture-run.jpeg`](G-wireshark/G0-capture-run.jpeg), [`pcap/full-flow-151340.pcap`](pcap/full-flow-151340.pcap) |
| **DNS** query + response (client:ephemeral → 10.7.19.6:53/UDP, answer 10.7.27.44) | [`G-wireshark/G1-dns-query-response-nishant.png`](G-wireshark/G1-dns-query-response-nishant.png) |
| **TCP** SYN → SYN-ACK → ACK, ports 60824 → 443, seq/ack | [`G-wireshark/G2-G3-tcp-tls-handshake.png`](G-wireshark/G2-G3-tcp-tls-handshake.png) |
| **TLS** ClientHello, ServerHello, Certificate, ChangeCipherSpec, encrypted Application Data | [`G-wireshark/G2-G3-tcp-tls-handshake.png`](G-wireshark/G2-G3-tcp-tls-handshake.png), [`G-wireshark/G8-flow-graph.jpeg`](G-wireshark/G8-flow-graph.jpeg) |
| SNI in ClientHello | [`G-wireshark/G6-client-hello-sni.jpeg`](G-wireshark/G6-client-hello-sni.jpeg) |
| Certificate packet (TLS 1.2) | [`G-wireshark/G5-certificate.jpeg`](G-wireshark/G5-certificate.jpeg) |
| TLS 1.3: certificate encrypted (comparison) | [`G-wireshark/G9-tls13-no-certificate.jpeg`](G-wireshark/G9-tls13-no-certificate.jpeg) |
| HTTP headers (why encrypted on the wire) | [`http/curl-v.txt`](http/curl-v.txt), E4 screenshots |
| Load balancing across both backends | D1, D2 |
| Edge → backend is plain HTTP (TLS terminated at edge) | [`G-wireshark/G10-edge-to-backend-plain-http-nishant.jpeg`](G-wireshark/G10-edge-to-backend-plain-http-nishant.jpeg) |

## Required failure demonstrations
All five, with exact commands, output, explanation and restore step:
[`H-failures/H-failure-demos.md`](H-failures/H-failure-demos.md)

| # | Failure | Result |
|---|---|---|
| H1 | Wrong DNS server on client | `cannot resolve`, but `ping 10.7.27.44` works |
| H2 | DNS record → wrong IP | `dig` → 10.7.23.55, curl `Couldn't connect` |
| H3 | One backend stopped | 6/6 served by B, 0 failures |
| H4 | Both backends stopped | `HTTP/2 502 Bad Gateway` from nginx |
| H5 | Wrong destination port | ping OK, port 8444 `Couldn't connect` |

---

# Phase 2 – Harden, Recover, Troubleshoot (2026-11-23/24)

Final report: [`../docs/PHASE2-REPORT.md`](../docs/PHASE2-REPORT.md) · all files in [`phase2/`](phase2/)
Laptops this session: L1 Priyansh `10.7.26.79` (primary DNS, client) · L2 Bhavay `10.7.13.123` (edge + Backend B) · L3 Nishant `10.7.19.207` (Backend A, backup DNS, standby edge).

| Item | Evidence |
|---|---|
| Phase 2 starting point (gate passes on the new IPs) | [`phase2/S1-gate-passed.txt`](phase2/S1-gate-passed.txt) |
| **Ext A – backup DNS**: both servers answer | [`phase2/extA-A2-both-dns-answering.txt`](phase2/extA-A2-both-dns-answering.txt), backup started: [`phase2/extA-A1-backup-dns-started-nishant.webp`](phase2/extA-A1-backup-dns-started-nishant.webp) |
| **Ext A** – primary stopped, backup answers (`SERVER: 10.7.19.207`), service still `HTTP 200` | [`phase2/extA-backup-dns-failover.txt`](phase2/extA-backup-dns-failover.txt) |
| **Ext B – TTL 30**: server changes at once, OS cache keeps old IP 29 s | [`phase2/extB-ttl-timeline.txt`](phase2/extB-ttl-timeline.txt) |
| **Ext B** – manual cache flush switches immediately | [`phase2/extB-flush-timeline.txt`](phase2/extB-flush-timeline.txt) |
| **Ext C – firewall**: before (direct access works) | [`phase2/extC-1-before.txt`](phase2/extC-1-before.txt) |
| **Ext C** – rules loaded on both backend laptops | [`phase2/extC-C1-firewall-on-nishant.webp`](phase2/extC-C1-firewall-on-nishant.webp), [`phase2/extC-C1-firewall-on-bhavay.webp`](phase2/extC-C1-firewall-on-bhavay.webp) |
| **Ext C** – direct blocked, through the edge 200 | [`phase2/extC-2-isolation.txt`](phase2/extC-2-isolation.txt) |
| **Ext C** – rollback (rules removed, direct access works again) | [`phase2/extC-3-rollback-check.txt`](phase2/extC-3-rollback-check.txt) |
| **Ext D – failover**: Backend A stopped under load (0 failed), then restarted and rejoined | [`phase2/extD-failover.txt`](phase2/extD-failover.txt) · discarded first attempt: [`phase2/extD-attempt1-connectivity-glitch-NOT-failover.txt`](phase2/extD-attempt1-connectivity-glitch-NOT-failover.txt) |
| **Ext E – standby edge** answers by name | [`phase2/extE-1-standby-edge.txt`](phase2/extE-1-standby-edge.txt) |
| **Ext E – DNS cutover**: `X-Edge` primary → standby → primary, 0 failed | [`phase2/extE-cutover.txt`](phase2/extE-cutover.txt) · first attempt (no cutover happened): [`phase2/extE-attempt1-no-cutover-happened.txt`](phase2/extE-attempt1-no-cutover-happened.txt) |
| **Ext F – troubleshooting**: layer-by-layer diagnosis, Backend B found down, fixed | [`phase2/extF-troubleshooting.txt`](phase2/extF-troubleshooting.txt) |

## Phase 2 – screenshots from the teammates' Macs ([`phase2/screenshots/`](phase2/screenshots/))

| Step | Screenshot |
|---|---|
| Setup – Nishant pulled the new IPs, rendered configs, roles listed (Backup DNS, Standby edge, Backend A), Backend A started | [`S2-setup-nishant-pull-render-whoami-backendA-started.jpeg`](phase2/screenshots/S2-setup-nishant-pull-render-whoami-backendA-started.jpeg) |
| Setup – Bhavay pulled/rendered, roles listed (Edge nginx, Backend B) | [`S2-setup-bhavay-pull-render-whoami.jpeg`](phase2/screenshots/S2-setup-bhavay-pull-render-whoami.jpeg) |
| Setup – Backend B listening on 10.7.13.123:3002 | [`S3-bhavay-backendB-running.jpeg`](phase2/screenshots/S3-bhavay-backendB-running.jpeg) |
| Setup – primary edge started, pool A=10.7.19.207:3001 B=10.7.13.123:3002 | [`S3-bhavay-edge-started.jpeg`](phase2/screenshots/S3-bhavay-edge-started.jpeg) |
| Setup – clients use the team DNS (`nameserver 10.7.26.79 / 10.7.19.207`), `dig` → 10.7.13.123 | [`S4-bhavay-client-dns-set-dig-ok.jpeg`](phase2/screenshots/S4-bhavay-client-dns-set-dig-ok.jpeg), [`S4-nishant-client-dns-set-dig-ok.jpeg`](phase2/screenshots/S4-nishant-client-dns-set-dig-ok.jpeg) |
| **Ext A** – backup DNS running on Nishant's Mac (10.7.19.207:53, 8 names) | [`extA-A1-nishant-backup-dns-running.jpeg`](phase2/screenshots/extA-A1-nishant-backup-dns-running.jpeg) |
| **Ext C** – firewall ON, rules listed (only 10.7.13.123 may reach 3001/3002) | [`extC-C1-nishant-firewall-on-original.jpeg`](phase2/screenshots/extC-C1-nishant-firewall-on-original.jpeg), [`extC-C1-bhavay-firewall-on-original.jpeg`](phase2/screenshots/extC-C1-bhavay-firewall-on-original.jpeg) |
| **Ext C** – firewall OFF, "Isolation OFF – original firewall configuration restored" | [`extC-C3-nishant-firewall-off.jpeg`](phase2/screenshots/extC-C3-nishant-firewall-off.jpeg), [`extC-C3-bhavay-firewall-off.jpeg`](phase2/screenshots/extC-C3-bhavay-firewall-off.jpeg) |
| **Ext C** – after rollback `pfctl -a com.apple/cnproject -s rules` prints no rules | [`extC-C3-bhavay-rules-empty-after-rollback-and-cert-share.jpeg`](phase2/screenshots/extC-C3-bhavay-rules-empty-after-rollback-and-cert-share.jpeg), [`extE-E1-and-C3-nishant-standby-dns-point-rules-empty.jpeg`](phase2/screenshots/extE-E1-and-C3-nishant-standby-dns-point-rules-empty.jpeg) |
| **Ext D** – edge log: requests alternating, then the retries (`upstream=10.7.19.207:3001, 10.7.13.123:3002 upstream_status=502, 200`) while Backend A was down, then A rejoining | [`extD-D2-bhavay-edge-log-failover-retries-then-recovery.jpeg`](phase2/screenshots/extD-D2-bhavay-edge-log-failover-retries-then-recovery.jpeg), [`extD-D2-bhavay-edge-log-before-and-attempt.jpeg`](phase2/screenshots/extD-D2-bhavay-edge-log-before-and-attempt.jpeg) |
| **Ext E** – standby edge started on Nishant's Mac (`standby edge started`, TLS terminated here, HTTP/2) | [`extE-E1-nishant-standby-edge-started.jpeg`](phase2/screenshots/extE-E1-nishant-standby-edge-started.jpeg), [`extE-E1-and-C3-nishant-standby-dns-point-rules-empty.jpeg`](phase2/screenshots/extE-E1-and-C3-nishant-standby-dns-point-rules-empty.jpeg) |
| Server certificate files shared to Nishant for the standby edge (temporary LAN share, then removed) | [`extC-C3-bhavay-rules-empty-after-rollback-and-cert-share.jpeg`](phase2/screenshots/extC-C3-bhavay-rules-empty-after-rollback-and-cert-share.jpeg) |
