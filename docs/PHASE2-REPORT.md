# Phase 2 Final Report – Team `team1` (Priyansh, Bhavay)

> Template: fill in the *italic* parts with your own results and observations from the real runs.

## 1. What changed from Phase 1

- Backup DNS resolver on Laptop 2 with the same records. Both laptops list two DNS servers.
- DNS TTL fixed at 30 s. Records moved to a reloadable hosts file so they can change live.
- pf firewall anchor on the backend machine. Only the edge may reach ports 3001/3002.
- nginx passive health checks + automatic retry on the other backend.
- Standby nginx edge on Laptop 1 with the same config and certificate, for DNS-based cutover.

## 2. Resilience tests and results

| Test | Expected | Observed | Evidence file |
|---|---|---|---|
| Primary DNS stopped | names still resolve via the backup | *e.g. first lookup took ~X s, then instant* | `evidence/phase2/extA-*.png` |
| Record changed, TTL 30 | old IP until the TTL expires, then the new one | *switched after N s* | `extB-watch.txt` |
| Flush DNS cache | new IP immediately | | |
| Direct access to 3001/3002 from L1 | blocked (timeout) | | `extC-*.txt` |
| Access through the edge with firewall on | 200 | | |
| Backend A stopped | 100% of requests served by B, 0 errors | *x/x requests OK* | `extD-*.txt` |
| Backend A restarted | back in rotation after ≤10 s | | |
| DNS cutover to standby edge | cached clients still hit primary ≤30 s, new lookups hit standby | | `extE-*.txt` |

## 3. Troubleshooting findings (Extension F)

*Fault injected by faculty → the layer we identified → commands that showed it → fix.*

## 4. Learning summary (one paragraph per extension)

**A – Backup DNS:** *…*

**B – TTL & record change:** *…*

**C – Service isolation:** *…*

**D – HA failover (and the remaining SPOF):** *…*

**E – Edge migration:** *…*

**F – Troubleshooting:** *…*
