# CN Project – Private Network Service Platform

A client types `https://app.team1.test`, which **our own DNS** resolves to **our own edge**.
The edge terminates **TLS** and **load-balances** the request to one of **two backends**.
Every step can be captured in Wireshark.

> *The application stays simple – the network is the project.*

Team (current): **Priyansh** (Laptop 1) and **Bhavay** (Laptop 2).
The project rules allow 1–4 members, and teams of 2–3 may combine machine roles.
If more members join, see [docs/04-FOUR-MEMBER-SPLIT.md](docs/04-FOUR-MEMBER-SPLIT.md). The only thing that changes is `team.env`.

---

## 2-member layout

```
                 private Wi-Fi / hotspot  (same subnet, e.g. 192.168.1.0/24)
   ┌──────────────────────────────────┐          ┌──────────────────────────────────────────┐
   │ LAPTOP 1 – Priyansh  ("Mac 1")   │          │ LAPTOP 2 – Bhavay  ("Mac 2 + 3 + 4")     │
   │                                  │  DNS     │                                          │
   │  Test client (curl / browser) ───┼─UDP 53──►│  (backup DNS, Phase 2 Ext A)             │
   │  Primary DNS  dnsmasq :53  ◄─────┼──────────┤  Edge: nginx :443 TLS + load balancer    │
   │  (standby edge, Phase 2 Ext E)   │  HTTPS   │      ├─► Backend A  python :3001         │
   │                               ───┼─TCP 443─►│      └─► Backend B  python :3002         │
   └──────────────────────────────────┘          └──────────────────────────────────────────┘
```

| Role (from the PDF) | Runs on | Start command |
|---|---|---|
| Mac 1 – Private DNS + test client | Laptop 1 (Priyansh) | `./scripts/start-dns.sh primary` |
| Mac 2 – Edge / reverse proxy / LB | Laptop 2 (Bhavay) | `./scripts/start-edge.sh primary` |
| Mac 3 – Backend A | Laptop 2 (Bhavay) | `./scripts/start-backend.sh A` |
| Mac 4 – Backend B | Laptop 2 (Bhavay) | `./scripts/start-backend.sh B` |
| Ext A – Backup DNS | Laptop 2 (Bhavay) | `./scripts/start-dns.sh backup` |
| Ext E – Standby edge | Laptop 1 (Priyansh) | `./scripts/start-edge.sh standby` |

**Why this split:** the client and DNS are on a different laptop from the edge and backends.
So every client request **really crosses the LAN**, and Wireshark shows real DNS, TCP and TLS
packets between two machines. It also makes Extension C (firewall) clean: the client laptop is
blocked, and the edge (same laptop as the backends) is allowed.

---

## Folder map

```
team.env                 ← the ONLY file you edit (IPs, team id, ports, roles)
backend/server.py        Task C – the tiny REST backend (Python stdlib, nothing to install)
templates/               config templates (dnsmasq, DNS records, nginx, pf firewall)
build/                   GENERATED configs  (./scripts/render.sh)  – don't edit
certs/                   GENERATED CA + server certificate (./scripts/make-certs.sh)
run/                     runtime files: logs, pid files, backups
evidence/                screenshots, pcaps and outputs for the evaluator
scripts/                 every action is one script (list below)
docs/                    runbook, concepts (viva prep), demo script, architecture, report
```

| Script | Purpose | PDF item |
|---|---|---|
| `render.sh` | generate all configs from `team.env` | – |
| `whoami.sh` | which roles does THIS laptop play | – |
| `network-info.sh` | IP, mask, gateway, interface, MAC → evidence | Task A |
| `ping-all.sh` | reachability to every team machine → evidence | Task A |
| `start-dns.sh primary\|backup` | run dnsmasq (foreground, logs every query) | Task B, Ext A |
| `set-client-dns.sh` / `restore-client-dns.sh` | point this Mac at the team DNS / undo | Task B, Ext A |
| `check-dns.sh` | dig / dscacheutil / nslookup → evidence | Task B |
| `start-backend.sh A\|B` | run a backend (foreground) | Task C |
| `make-certs.sh` / `trust-ca.sh` | create our CA + cert / trust the CA on a Mac | Task E |
| `start-edge.sh` / `stop-edge.sh` / `edge-logs.sh` | nginx edge | Task D/E, Ext E |
| `test-lb.sh` | N requests, show `X-Backend` / `X-Edge` | Task D, Ext D/E |
| `test-cache.sh` | 200 vs 304, Cache-Control, ETag → evidence | Task F |
| `capture.sh <name> [--auto]` | tcpdump → `evidence/pcap/*.pcap` for Wireshark | Task G |
| `verify.sh` | automatic Phase 1 gate check | Phase 1 gate |
| `flush-dns.sh` / `watch-dns.sh` / `dns-point-app.sh` | TTL + DNS cutover experiments | Ext B, Ext E |
| `firewall-on.sh` / `firewall-off.sh` / `test-isolation.sh` | backend isolation | Ext C |

---

## Quick start (details: [docs/01-RUNBOOK.md](docs/01-RUNBOOK.md))

```bash
# BOTH laptops, once
brew install nginx dnsmasq && brew install --cask wireshark
./scripts/network-info.sh            # note your IP, put both IPs into team.env (identical on both)
./scripts/render.sh && ./scripts/whoami.sh && ./scripts/ping-all.sh

# LAPTOP 2 (Bhavay)
./scripts/start-backend.sh A         # terminal tab 1
./scripts/start-backend.sh B         # terminal tab 2
./scripts/make-certs.sh              # then AirDrop the certs/ folder to Laptop 1
./scripts/start-edge.sh primary

# LAPTOP 1 (Priyansh)
./scripts/start-dns.sh primary       # terminal tab 1, leave it running

# BOTH laptops (clients)
./scripts/set-client-dns.sh && ./scripts/trust-ca.sh

# LAPTOP 1 – prove it
./scripts/verify.sh                  # Phase 1 gate
```

## Docs

1. [docs/01-RUNBOOK.md](docs/01-RUNBOOK.md) – step-by-step build for Phase 1 and Phase 2, plus troubleshooting
2. [docs/02-CONCEPTS.md](docs/02-CONCEPTS.md) – **viva prep**: every concept explained, with likely questions
3. [docs/03-DEMO-SCRIPT.md](docs/03-DEMO-SCRIPT.md) – the 11-step final demo, command by command
4. [docs/04-FOUR-MEMBER-SPLIT.md](docs/04-FOUR-MEMBER-SPLIT.md) – what to change if 2 more members join
5. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) – architecture document deliverable (topology, IP table, flow)
6. [docs/PHASE2-REPORT.md](docs/PHASE2-REPORT.md) – Phase 2 final report template
