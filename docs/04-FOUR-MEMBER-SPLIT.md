# If two more members join – switching from 2 to 4 laptops

Nothing in the code changes. Every script reads roles from `team.env`, so you only re-map roles to
laptops.

## New layout (matches the PDF's recommended architecture exactly)

| Laptop | Member | Role(s) | Commands |
|---|---|---|---|
| Mac 1 | Priyansh | Primary DNS + test client | `start-dns.sh primary` |
| Mac 2 | Bhavay | Edge nginx (reverse proxy + LB + TLS) | `make-certs.sh`, `start-edge.sh primary` |
| Mac 3 | Member 3 | Backend A · *standby edge (Ext E)* | `start-backend.sh A`, later `start-edge.sh standby` |
| Mac 4 | Member 4 | Backend B + test client · *backup DNS (Ext A)* | `start-backend.sh B`, `start-dns.sh backup` |

## What to do

1. In `team.env`, add `LAPTOP3_IP` / `LAPTOP4_IP` and replace the role block with the
   commented **4-member layout** that's already in the file:
   ```bash
   DNS_PRIMARY_IP="${LAPTOP1_IP}"
   DNS_BACKUP_IP="${LAPTOP4_IP}"
   EDGE_IP="${LAPTOP2_IP}"
   EDGE_STANDBY_IP="${LAPTOP3_IP}"
   BACKEND_A_IP="${LAPTOP3_IP}"
   BACKEND_B_IP="${LAPTOP4_IP}"
   ```
2. Copy the same `team.env` to all four laptops and run `./scripts/render.sh` on each.
   `./scripts/whoami.sh` tells each person what to start.
3. Copy `certs/` from Mac 2 to everyone. Every client runs `trust-ca.sh`, and Mac 3 needs `server.*` for the standby edge.
4. Every laptop runs `./scripts/set-client-dns.sh`, which gives three Macs using Mac 1 as their resolver (Task B wants at least two).
5. `./scripts/ping-all.sh` on all four laptops covers every pair (Task A).

## What gets better with 4 members (mention it in the report)

- **Edge → backend traffic now crosses the LAN.** You can capture it on Mac 3/4 and show that it's
  plain HTTP (TLS was terminated at Mac 2), with `X-Forwarded-For` visible.
- **Ext C** is more meaningful: run `firewall-on.sh` on **Mac 3 and Mac 4**. Mac 1 is blocked and Mac 2 is allowed.
- **Ext D** is a real machine failure: you can shut a whole laptop's lid instead of stopping a process.
- **SPOF analysis:** only Mac 2 (the edge) remains a single point of failure, not "Mac 2 + backends".

## Splitting the work (suggestion)

| Member | Owns (but everyone must be able to explain everything) |
|---|---|
| Priyansh | DNS (Task B, Ext A, Ext B), Wireshark evidence (Task G) |
| Bhavay | Edge: nginx, TLS, load balancing (Task D, E, Ext D, Ext E) |
| Member 3 | Backend A, caching (Task C, F), firewall (Ext C) |
| Member 4 | Backend B, failure demos, architecture doc + final report |

With **2 members** (now): Priyansh owns DNS, client-side tests, Wireshark, Ext A/B/E and the docs.
Bhavay owns the backends, certificates, nginx, firewall and Ext C/D. Swap and rehearse each other's
part before the viva.

## If only ONE more member joins (3 laptops)

Move the backends off the edge:
```bash
DNS_PRIMARY_IP="${LAPTOP1_IP}"; DNS_BACKUP_IP="${LAPTOP3_IP}"
EDGE_IP="${LAPTOP2_IP}";        EDGE_STANDBY_IP="${LAPTOP1_IP}"
BACKEND_A_IP="${LAPTOP3_IP}";   BACKEND_B_IP="${LAPTOP3_IP}"
```
