# CN Project – Private Network Service Platform

A client types `https://app.team67.test`, which **our own DNS** resolves to **our own edge**.
The edge terminates **TLS** and **load-balances** the request to one of **two backends**.
Every step can be captured in Wireshark.

> *The application stays simple – the network is the project.*

Team: **Priyansh** (Laptop 1), **Bhavay** (Laptop 2), **Nishant** (Laptop 3).
The project rules allow 1–4 members, and teams of 2–3 may combine machine roles.
For other team sizes see [docs/04-TEAM-SPLIT.md](docs/04-TEAM-SPLIT.md). The only thing that changes is `team.env`.

---

## 3-member layout

```
                      private Wi-Fi / hotspot  (same subnet)
 ┌────────────────────────────┐   ┌────────────────────────────────┐   ┌────────────────────────────────┐
 │ LAPTOP 1 – Priyansh        │   │ LAPTOP 2 – Bhavay              │   │ LAPTOP 3 – Nishant             │
 │ "Mac 1"                    │   │ "Mac 2 + Mac 4"                │   │ "Mac 3"                        │
 │                            │   │                                │   │                                │
 │ Test client (curl/browser) │   │ Edge: nginx :443               │   │ Backend A  python :3001        │
 │ Primary DNS dnsmasq :53    │   │   TLS + round-robin LB ────────┼──►│                                │
 │                            │   │   └─► Backend B python :3002   │   │ (backup DNS :53, Ext A)        │
 │                            │   │                                │   │ (standby edge :443, Ext E)     │
 └────────────────────────────┘   └────────────────────────────────┘   └────────────────────────────────┘
   client ── DNS udp/53 ──► L1 (backup: L3)        client ── HTTPS tcp/443 ──► L2 ──► A on L3 / B on L2
```

| Role (from the PDF) | Runs on | Start command |
|---|---|---|
| Mac 1 – Private DNS + test client | Laptop 1 (Priyansh) | `./scripts/start-dns.sh primary` |
| Mac 2 – Edge / reverse proxy / LB | Laptop 2 (Bhavay) | `./scripts/start-edge.sh primary` |
| Mac 3 – Backend A | Laptop 3 (Nishant) | `./scripts/start-backend.sh A` |
| Mac 4 – Backend B | Laptop 2 (Bhavay) | `./scripts/start-backend.sh B` |
| Ext A – Backup DNS | Laptop 3 (Nishant) | `./scripts/start-dns.sh backup` |
| Ext E – Standby edge | Laptop 3 (Nishant) | `./scripts/start-edge.sh standby` |

**Why this split**
- The client and DNS are on their own laptop, so every client request **really crosses the LAN**.
- Backend A is on a **separate machine** from the edge, so edge→backend traffic crosses the LAN too.
  For the Ext D failover demo you can shut Nishant's laptop entirely, and Backend B keeps serving.
- Task B ("configure at least two other Macs to use Mac 1 as resolver") is now met exactly: L2 and L3.
- Ext C: the firewall runs on both backend machines (L2, L3). The edge (L2) is allowed, and the client (L1) is blocked.
- The work is spread evenly. Each person runs 2–3 services.

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
# ALL 3 laptops, once
brew install nginx dnsmasq openssl@3 && brew install --cask wireshark
./scripts/network-info.sh            # note your IP, put all 3 IPs into team.env (identical everywhere)
./scripts/render.sh && ./scripts/whoami.sh && ./scripts/ping-all.sh

# LAPTOP 3 (Nishant)
./scripts/start-backend.sh A         # own terminal tab

# LAPTOP 2 (Bhavay)
./scripts/start-backend.sh B         # own terminal tab
./scripts/make-certs.sh              # then AirDrop certs/ to Laptop 1 and Laptop 3
./scripts/start-edge.sh primary

# LAPTOP 1 (Priyansh)
./scripts/start-dns.sh primary       # terminal tab 1, leave it running

# ALL 3 laptops (clients)
./scripts/set-client-dns.sh && ./scripts/trust-ca.sh

# LAPTOP 1 – prove it
./scripts/verify.sh                  # Phase 1 gate
```

## Docs

1. [docs/01-RUNBOOK.md](docs/01-RUNBOOK.md) – step-by-step build for Phase 1 and Phase 2, plus troubleshooting
2. [docs/02-CONCEPTS.md](docs/02-CONCEPTS.md) – **viva prep**: every concept explained, with likely questions
3. [docs/03-DEMO-SCRIPT.md](docs/03-DEMO-SCRIPT.md) – the 11-step final demo, command by command
4. [docs/04-TEAM-SPLIT.md](docs/04-TEAM-SPLIT.md) – who owns what, and how to switch to 2 or 4 members
5. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) – architecture document deliverable (topology, IP table, flow)
6. [docs/PHASE2-REPORT.md](docs/PHASE2-REPORT.md) – Phase 2 final report template
