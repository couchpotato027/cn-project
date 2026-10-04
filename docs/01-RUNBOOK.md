# Runbook – building the project step by step (2 members)

**L1** = Laptop 1, Priyansh (DNS + client). **L2** = Laptop 2, Bhavay (edge + backends).
Run every command from the project folder (`cd ~/Desktop/CN_Project`).
Commands that need your Mac password say so. Scripts that run in the *foreground*
(DNS, backends) each need their **own Terminal tab** (⌘T).

---

## Step 0 – Preparation (both laptops, once)

1. **Get the same project folder on both laptops.** Push it to a private GitHub repo and clone it
   on both (`certs/` and `run/` are git-ignored on purpose), or AirDrop the folder.
2. **Install the tools**
   ```bash
   brew install nginx dnsmasq
   brew install --cask wireshark
   ```
3. **Pick a network.** College Wi-Fi often has *client isolation*, which means laptops can't
   reach each other. A phone hotspot or a home router always works. Both laptops must
   join **the same** network.
4. **macOS settings that silently break things.** Check these now:
   - *System Settings → Privacy & Security → Local Network*: turn **Terminal** (or iTerm) **on**.
     Without this, curl to another laptop fails with "No route to host".
   - Turn **VPNs off**.
   - Turn **iCloud Private Relay off** for this Wi-Fi (Wi-Fi → Details → Limit IP address tracking off).
   - In Chrome: *Settings → Privacy and security → Security → Use secure DNS* → **off**. Otherwise
     Chrome skips our DNS server and `.test` names won't resolve.
   - If the macOS firewall is on and asks "Allow incoming connections?" for python3, nginx or
     dnsmasq, click **Allow**.

---

## PHASE 1 – Build & Observe

### Task A – Establish the private LAN (both laptops)

```bash
./scripts/network-info.sh      # prints + saves IP, mask/prefix, gateway, interface, MAC
```
1. Put **both** IPs into `team.env` (`LAPTOP1_IP`, `LAPTOP2_IP`). Also set `TEAM_ID` to your
   real team number. **The file must be identical on both laptops.**
2. Then:
   ```bash
   ./scripts/render.sh            # generates build/ configs
   ./scripts/whoami.sh            # confirms which roles this laptop has
   ./scripts/ping-all.sh          # proves reachability -> evidence/taskA/
   ```
3. Draw the topology diagram. A template is in [ARCHITECTURE.md](ARCHITECTURE.md).

> DHCP can give you a new IP the next day. Before every session/demo, re-run `network-info.sh`.
> If an IP changed, update `team.env` on both laptops, run `render.sh`, and restart the services.

### Task C – Two backends (L2)

```bash
./scripts/start-backend.sh A       # tab 1  -> port 3001
./scripts/start-backend.sh B       # tab 2  -> port 3002
```
Test from **L1**. This talks to the backends directly, which is allowed for testing only:
```bash
curl -i http://<L2-IP>:3001/api/status      # X-Backend: A
curl -i http://<L2-IP>:3002/api/status      # X-Backend: B
```
They listen on `0.0.0.0` (all interfaces). If they listened only on `127.0.0.1`, other machines
couldn't reach them.

### Task E (part 1) – Certificates (L2)

```bash
./scripts/make-certs.sh
```
This creates `certs/ca.crt` (our CA), `certs/ca.key` (the CA's secret key) and
`certs/server.crt` + `certs/server.key` (nginx's certificate for app/api.team1.test).
**AirDrop the whole `certs/` folder to L1.** L1 needs `ca.crt` to trust the CA, and
`server.*` for the standby edge in Ext E.

### Task D + E – Edge reverse proxy, load balancer, TLS (L2)

```bash
./scripts/start-edge.sh primary
./scripts/edge-logs.sh primary         # optional, in another tab: live request log
```

### Task B – Private DNS (L1)

```bash
./scripts/start-dns.sh primary         # own tab; asks for your Mac password (port 53)
```
dnsmasq prints every query it receives, so leave this tab visible during demos.

### Point both laptops at the team DNS + trust the CA (L1 and L2)

```bash
./scripts/set-client-dns.sh            # DNS = L1 (primary), L2 (backup)   [password]
./scripts/trust-ca.sh                  # add our CA to the System keychain [password]
```
This configures **two Macs** (L1 and L2) to resolve through L1's DNS server. That covers Task B's
"configure at least two Macs" with the machines a 2-person team has. Confirm this with your faculty.

### Verify the Phase 1 gate (L1)

```bash
./scripts/check-dns.sh                 # Task B evidence
./scripts/verify.sh                    # automatic gate check: should end with "PHASE 1 GATE PASSED"
./scripts/test-lb.sh                   # Task D: A, B, A, B ...
./scripts/test-cache.sh                # Task F: 200 -> 304
```
In the browser, open **https://app.team1.test**. You should see a padlock and no warning.
Use Safari or Chrome. Firefox has its own certificate store and won't trust our CA.

> **About curl and `--cacert`.** The scripts pass `--cacert certs/ca.crt` to curl. This is **not**
> `-k`. The certificate is still fully checked (signature, expiry, hostname); we only tell curl
> which CA to trust. Browsers use the System keychain, which `trust-ca.sh` already set up.

### Task G – Capture the complete protocol flow (L1)

```bash
./scripts/capture.sh full-flow --auto    # [password] captures DNS + TCP + TLS 1.2 + TLS 1.3
open -a Wireshark evidence/pcap/full-flow-*.pcap
```
Or capture while you click around in the browser yourself:
```bash
./scripts/capture.sh browser             # Ctrl+C when done
```
Wireshark display filters to screenshot (save into `evidence/screenshots/`):

| Show | Filter | What to point at |
|---|---|---|
| DNS | `dns` | query `app.team1.test` from client:ephemeral → L1:53/UDP; response with L2's IP and TTL 30 |
| TCP handshake | `tcp.flags.syn==1 \|\| tcp.flags.ack==1 && tcp.len==0` | SYN → SYN-ACK → ACK, ports client:5xxxx → L2:443 |
| TCP seq/ack | any TCP packet → *Transmission Control Protocol* panel | relative Seq/Ack numbers, Window size |
| TLS handshake | `tls.handshake` | ClientHello (has SNI `app.team1.test`), ServerHello, Certificate, ChangeCipherSpec, Finished |
| Certificate | `tls.handshake.type == 11` | only visible in the **TLS 1.2** connection (TLS 1.3 encrypts it) |
| Encrypted data | `tls.app_data` | "Application Data", unreadable, so HTTP is hidden |

Save the HTTP-header evidence with `curl -v https://app.team1.test/api/status 2>&1 | tee evidence/http/curl-v.txt`.

### Phase 1 – required failure demonstrations

| Failure | How to cause it | What you'll see | Undo |
|---|---|---|---|
| Wrong DNS server on a client | L1: `./scripts/set-client-dns.sh --wrong` | `ping app.team1.test` → "cannot resolve", but `ping <L2-IP>` works. DNS and IP are independent. | `./scripts/set-client-dns.sh` |
| DNS record points to wrong IP | on L1: `./scripts/dns-point-app.sh 192.168.1.250` (an unused IP on your subnet), then `./scripts/flush-dns.sh` | `dig` succeeds with the wrong IP. curl times out or is refused. DNS is a directory, not a connection. | `./scripts/dns-point-app.sh edge` |
| One backend stopped | L2: Ctrl+C in Backend A's tab | `./scripts/test-lb.sh` → all B, zero errors | restart A |
| Both backends stopped | L2: Ctrl+C both | DNS + TLS still work, `curl` → **502 Bad Gateway** from nginx. That's where the edge ends. | restart both |
| Wrong destination port | L1: `curl https://app.team1.test:8444/` | ping works, but the TCP connection is refused (RST). IP and port are separate identifiers. | – |

---

## PHASE 2 – Harden, Recover, Troubleshoot

### Extension A – Backup DNS resolver (L2 runs it, L1 tests)

```bash
# L2
./scripts/start-dns.sh backup            # own tab; same records as the primary
# L1
./scripts/check-dns.sh                   # both servers answer
# L1: stop the primary  -> Ctrl+C in the primary DNS tab
./scripts/flush-dns.sh
dig app.team1.test                       # the first query may take ~1-5 s (primary times out), then works
dscacheutil -q host -a name app.team1.test
curl https://app.team1.test/api/status --cacert certs/ca.crt   # still works
```
Explain the difference. **DNS failure**: the name can't be resolved, so nothing even starts.
**App server failure**: the name resolves and TCP/TLS to the edge work, but you get a 502.
Restart the primary afterwards.

### Extension B – TTL and a controlled record change (L1)

```bash
./scripts/watch-dns.sh                   # tab A: OS answer vs. server answer, every 3 s
./scripts/dns-point-app.sh 192.168.1.250 # tab B (run on BOTH DNS laptops, or stop the backup)
```
Watch tab A. The **server** answer changes immediately. The **OS resolver** keeps the old IP until
the 30 s TTL expires, then switches. Repeat the change, then run `./scripts/flush-dns.sh`, and
the OS switches at once. Finally run `./scripts/dns-point-app.sh edge` (on both DNS laptops).

### Extension C – Service isolation with pf firewall (L2 runs it, L1 tests)

```bash
# L2
./scripts/firewall-on.sh                 # [password] saves rollback copy, loads rules
# L1
./scripts/test-isolation.sh              # direct :3001/:3002 -> TIMEOUT, via edge -> 200
# L2 (afterwards - REQUIRED by the PDF)
./scripts/firewall-off.sh
```
The rules live in their own pf anchor, so macOS's default firewall config is never edited.

### Extension D – High-availability failover (L2 + L1)

```bash
# L1
./scripts/test-lb.sh 30 0.5              # keep it running
# L2: Ctrl+C Backend A while it runs  -> all requests go to B, 0 failures
# L2: ./scripts/start-backend.sh A      -> after <=10 s A rejoins the rotation
```
Look at `./scripts/edge-logs.sh` on L2. The failed attempt shows `upstream=<A>, <B>` (nginx retried B).
**Single point of failure:** the edge nginx on L2, and in our layout L2 *itself*, since it also
hosts both backends. See [02-CONCEPTS.md](02-CONCEPTS.md) §9 for how to eliminate it.

### Extension E – Controlled edge migration with a DNS cutover

Run Ext C's `firewall-off.sh` first. The standby edge on L1 must reach the backends on L2.
```bash
# L1  (needs certs/server.crt + server.key from L2)
./scripts/start-edge.sh standby
# L1, tab A
./scripts/test-lb.sh 40 1                 # watch the X-Edge column
# L1 and L2 (both DNS servers)
./scripts/dns-point-app.sh standby
```
For up to 30 s, clients with the old cached answer still hit `X-Edge: primary`. New lookups go to
`X-Edge: standby`. Cut back with `./scripts/dns-point-app.sh edge`, then `./scripts/stop-edge.sh standby`.

### Extension F – Faculty-injected fault

There's nothing to build here. Practise with [03-DEMO-SCRIPT.md](03-DEMO-SCRIPT.md) §F: one of you breaks
something, and the other diagnoses it layer by layer.

---

## Troubleshooting

| Symptom | Likely cause → fix |
|---|---|
| `ping` between laptops fails | not on the same network / client isolation → use a hotspot. Wrong IP in team.env → `network-info.sh`. |
| `ping` works but `curl http://<ip>:3001` says "No route to host" | macOS Local Network permission for Terminal (Step 0). |
| `curl` hangs to a backend port | macOS application firewall blocking python3 → allow it, or Ext C rules still loaded → `firewall-off.sh`. |
| `dig @<L1-IP> app.team1.test` times out | dnsmasq not running / wrong IP in team.env / firewall on L1 blocking dnsmasq. |
| `dig @L1` works but `dscacheutil` / browser doesn't | this Mac isn't using the team DNS → `set-client-dns.sh`. VPN, Private Relay or Chrome secure-DNS active. |
| `start-dns.sh`: "failed to create listening socket" | wrong `DNS_PRIMARY_IP` in team.env, or another DNS server already on :53 (`sudo lsof -nP -i :53`). |
| `start-edge.sh`: "Address already in use" | another nginx/web server is on 80/443 (`lsof -nP -i :443`). Stop it, or set `HTTP_PORT=8080` / `HTTPS_PORT=8443` in team.env and run `render.sh` (allowed by the PDF). |
| curl error 60 "unable to get local issuer certificate" | CA not trusted → `trust-ca.sh`, or pass `--cacert certs/ca.crt`. |
| curl error 60 "no alternative certificate subject name matches" | you used the IP or a wrong name → use `https://app.<team>.test`. |
| Browser warning after trusting | restart the browser. Make sure `TEAM_ID` was the same when the cert was made → re-run `make-certs.sh`, restart the edge. |
| 502 Bad Gateway | edge OK, backends unreachable → backends running? correct IPs? firewall? |
| Changing team.env did nothing | run `./scripts/render.sh` and restart DNS/edge. |

## Cleaning up after the project

```bash
./scripts/restore-client-dns.sh      # DNS back to automatic
./scripts/trust-ca.sh --remove       # remove our CA from the keychain
./scripts/firewall-off.sh            # if you used Ext C
./scripts/stop-edge.sh primary; ./scripts/stop-edge.sh standby
```
