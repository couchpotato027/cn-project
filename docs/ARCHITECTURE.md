# Architecture Document – Team `team67`

**Team:** Priyansh, Bhavay, Nishant · **Domain:** `team67.test` · **Network:** `<SSID>` · `10.7.0.0/19` (mask 255.255.224.0) · gateway `10.7.0.1`

## 1. Network topology

```mermaid
flowchart LR
  subgraph LAN["Private Wi-Fi / LAN"]
    subgraph L1["Laptop 1 - Priyansh (Mac 1)"]
      C["Test client\ncurl / browser"]
      D1["Primary DNS\ndnsmasq :53"]
    end
    subgraph L2["Laptop 2 - Bhavay (Mac 2 + Mac 4)"]
      E["Edge\nnginx :443 TLS + LB"]
      B["Backend B\n:3002"]
    end
    subgraph L3["Laptop 3 - Nishant (Mac 3)"]
      A["Backend A\n:3001"]
      D2["Backup DNS\ndnsmasq :53 (Ext A)"]
      S["Standby edge\nnginx :443 (Ext E)"]
    end
  end
  C -- "1 DNS query udp/53" --> D1
  C -. "backup" .-> D2
  C -- "2 HTTPS tcp/443" --> E
  E -- "3 HTTP round robin (across LAN)" --> A
  E -- "3 HTTP round robin (local)" --> B
```

## 2. Machine roles and IP / service table

| Machine | Member | Interface | IPv4 / prefix | MAC | PDF role(s) | Services (port) | Cloud equivalent |
|---|---|---|---|---|---|---|---|
| Laptop 1 | Priyansh | en0 | `10.7.19.6/19` | `be:ad:7d:98:37:82` | Mac 1: DNS + client | dnsmasq (53/udp+tcp) | Route 53 private hosted zone |
| Laptop 2 | Bhavay | en0 | `10.7.27.44/19` | `c2:f1:0a:e0:e1:08` | Mac 2: edge · Mac 4: backend B | nginx (80→443, 443), python (3002) | ALB / CDN edge + EC2 instance |
| Laptop 3 | Nishant | en0 | `10.7.23.55/19` | `76:b1:b9:ff:e0:4b` | Mac 3: backend A · backup DNS · standby edge | python (3001), dnsmasq (53), nginx standby (443) | EC2 instance, secondary DNS, standby LB |

(From `evidence/taskA/*.txt`, recorded 2026-10-05. Re-check before the demo: DHCP can change IPs. MACs are macOS private Wi-Fi addresses.)

## 3. DNS records (`build/dns/records.hosts`, TTL 30 s)

| Name | Type | Value | Purpose |
|---|---|---|---|
| app.team67.test | A | 10.7.27.44 (edge, L2) | the service |
| api.team67.test | A | 10.7.27.44 (edge, L2) | API alias |
| dns1 / dns2 / edge / edge-standby / backend-a / backend-b .team67.test | A | infra IPs | diagnostics only |

## 4. Request flow, with the protocol at each layer

```
Client (L1)               DNS (L1)        Edge nginx (L2)                   Backend A (L3) / B (L2)
   | DNS query A app.team67.test |                |                                    |
   |--- UDP :5xxxx -> :53 ----->|                |                                    |
   |<-- A <L2-IP> TTL 30 -------|                |                                    |
   |------------ TCP SYN :5xxxx -> :443 -------->|                                    |
   |<----------- SYN-ACK ------------------------|                                    |
   |------------ ACK --------------------------->|                                    |
   |== TLS ClientHello(SNI)/ServerHello+Cert/Fin=|                                    |
   |== HTTP/2 GET /api/status (encrypted) ======>| TLS terminated                     |
   |                                             |-- new TCP + HTTP/1.1 GET -> :3001 ->| (A, over the LAN)
   |                                             |<- 200 JSON, X-Backend: A ----------|
   |<= 200 JSON, X-Backend: A, X-Edge (encr.) ===|                                    |
```

| Layer | Protocol | Evidence |
|---|---|---|
| Application | DNS, HTTP/2 (client↔edge), HTTP/1.1 (edge↔backend) | `evidence/dns/`, `evidence/http/` |
| Presentation/Session | TLS 1.3 (1.2 for the certificate capture) | pcap: `tls.handshake` |
| Transport | UDP 53, TCP 443, TCP 3001/3002 | pcap: `tcp.flags.syn==1` |
| Network | IPv4, one subnet | `network-info.sh`, ping |
| Link | 802.11 Wi-Fi, MAC addresses | `network-info.sh` |

## 5. Phase 2 additions

| Extension | Change |
|---|---|
| A – Backup DNS | dnsmasq on L3 with identical records. Clients list L1, L3. |
| B – TTL | `local-ttl=30`. Live record change via SIGHUP (`dns-point-app.sh`). |
| C – Isolation | pf anchor `com.apple/cnproject` on L2 and L3: only the edge IP may reach 3001/3002. |
| D – HA | nginx `max_fails=1 fail_timeout=10s`, `proxy_next_upstream error timeout http_502 http_503`. |
| E – Edge migration | standby nginx on L3 (same config + cert). DNS cutover app → L3. |
| SPOF | L2: the only edge, and it also hosts Backend B. Mitigation: VRRP floating IP, a second edge with DNS health checks, or a managed LB. |
