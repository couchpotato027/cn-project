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
