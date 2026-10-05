# Team split – who runs what, who owns what

Nothing in the code depends on team size. Every script reads roles from `team.env`, so changing
team size = editing the role lines there, then `./scripts/render.sh` on every laptop.

## Current: 3 members

| Laptop | Member | PDF role | Services | Phase 2 extras |
|---|---|---|---|---|
| L1 | **Priyansh** | Mac 1 | Primary DNS (dnsmasq :53), test client | – |
| L2 | **Bhavay** | Mac 2 + Mac 4 | Edge nginx (:80→:443, TLS, LB), Backend B (:3002) | firewall (Ext C) |
| L3 | **Nishant** | Mac 3 | Backend A (:3001) | backup DNS (Ext A), standby edge (Ext E), firewall (Ext C) |

```bash
# team.env
DNS_PRIMARY_IP="${LAPTOP1_IP}"
DNS_BACKUP_IP="${LAPTOP3_IP}"
EDGE_IP="${LAPTOP2_IP}"
EDGE_STANDBY_IP="${LAPTOP3_IP}"
BACKEND_A_IP="${LAPTOP3_IP}"
BACKEND_B_IP="${LAPTOP2_IP}"
```

### Ownership (each person *leads* these; everyone must be able to explain everything)

| Member | Leads PDF items | Evidence they collect | Writes |
|---|---|---|---|
| **Priyansh** | Task A (LAN), Task B (DNS), Task G (Wireshark), Ext B (TTL) | `taskA/`, `dns/`, `pcap/` + screenshots, Ext B watch output | Architecture document |
| **Bhavay** | Task D (nginx LB), Task E (TLS/certs), Ext C (firewall), Ext D (failover) | `http/` (curl -v), browser padlock + keychain screenshots, edge log, isolation test | Configuration bundle notes |
| **Nishant** | Task C (backends), Task F (caching), Ext A (backup DNS), Ext E (edge migration) | `caching/`, edge→backend plain-HTTP capture, Ext A + Ext E results | Phase 2 final report |

Phase 1 failure demos: **everyone** runs one or two of them, so each person has practised a failure.
Ext F (troubleshooting): practise in rotation. One person injects a fault, and the other two diagnose it.

### Why the roles are placed like this

- **DNS alone on L1, with the client.** All client traffic (DNS + HTTPS) leaves L1 and crosses the LAN.
- **Backend A on its own laptop (L3).** Edge→backend traffic crosses the LAN, so you can capture the
  plain-HTTP leg. Ext D becomes a *real* machine failure: close Nishant's lid and B keeps serving.
- **Backend B on the edge (L2).** With 3 laptops, two roles have to share a machine. The edge + one
  backend is the pairing the PDF's 4-Mac design comes closest to, and the firewall rule still works
  (nginx reaches B locally).
- **Backup DNS and standby edge on L3, not L1.** The PDF requires the backup DNS to run on "another
  Mac (not Mac 1)", and suggests the standby edge on Mac 3. Putting both on L3 also means Ext A and
  Ext E survive if L1 or L2 goes down.
- **Remaining SPOF:** L2. It is the only edge, and it also hosts Backend B.

---

## Alternative: 2 members (L3 removed)

```bash
DNS_PRIMARY_IP="${LAPTOP1_IP}"; DNS_BACKUP_IP="${LAPTOP2_IP}"
EDGE_IP="${LAPTOP2_IP}";        EDGE_STANDBY_IP="${LAPTOP1_IP}"
BACKEND_A_IP="${LAPTOP2_IP}";   BACKEND_B_IP="${LAPTOP2_IP}"
```
L2 runs the edge and both backends, plus the backup DNS. L1 runs DNS, the client and the standby edge.

## Alternative: 4 members (matches the PDF's diagram exactly)

Add `LAPTOP4_IP` and use the commented 4-member block in `team.env`:
```bash
DNS_PRIMARY_IP="${LAPTOP1_IP}"; DNS_BACKUP_IP="${LAPTOP4_IP}"
EDGE_IP="${LAPTOP2_IP}";        EDGE_STANDBY_IP="${LAPTOP3_IP}"
BACKEND_A_IP="${LAPTOP3_IP}";   BACKEND_B_IP="${LAPTOP4_IP}"
```
| Laptop | Member | Roles |
|---|---|---|
| Mac 1 | Priyansh | Primary DNS + client |
| Mac 2 | Bhavay | Edge |
| Mac 3 | Nishant | Backend A · standby edge |
| Mac 4 | Member 4 | Backend B + client · backup DNS |

With 4 laptops the only SPOF is the edge (Mac 2), and the firewall runs on Mac 3 and Mac 4.
