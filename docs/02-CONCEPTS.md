# Concepts explained – what we built, how it works, and why (viva prep)

Priyansh, Bhavay and Nishant must all be able to explain **any** part of this, not only the part
they configured. Each section explains the concept with a link to the project, then lists
questions examiners are likely to ask.

---

## 1. The journey of ONE request (the big picture)

You run `curl https://app.team67.test/api/status` on Laptop 1:

| # | What happens | Protocol / layer | Where in our project |
|---|---|---|---|
| 1 | curl asks the OS "what's the IP of app.team67.test?" The OS checks its **DNS cache**. | – | macOS mDNSResponder |
| 2 | Cache miss: the OS sends a **DNS query** (UDP, source port random, dest port **53**) to the DNS server set in Network settings. | DNS over UDP | L1 → L1's dnsmasq |
| 3 | dnsmasq looks up its records file and answers **A record: app.team67.test → L2's IP, TTL 30**. The OS caches it for 30 s. | DNS | `build/dns/records.hosts` |
| 4 | curl opens a **TCP connection** to L2:443: SYN → SYN-ACK → ACK (3-way handshake). The client uses a random **ephemeral port** (e.g. 52314). | TCP | L1:52314 → L2:443 |
| 5 | **TLS handshake** on top of TCP. ClientHello (with SNI = app.team67.test) → ServerHello + Certificate → key exchange → Finished. curl **validates** the certificate against our CA. | TLS | nginx on L2, `certs/` |
| 6 | curl sends the **HTTP request** (HTTP/2) *inside* TLS, so on the wire it's encrypted "Application Data". | HTTP over TLS | – |
| 7 | nginx **decrypts** it (TLS termination), picks a backend by **round robin**, and opens a *new* plain-HTTP TCP connection to it, adding `X-Forwarded-For`. | HTTP, reverse proxy | `upstream backends {}` |
| 8 | The backend answers with JSON and the header `X-Backend: A`. | HTTP | `backend/server.py` |
| 9 | nginx adds `X-Edge`, encrypts the response, and sends it back over the TLS connection. | TLS | – |
| 10 | Connection closes: FIN/ACK exchange. | TCP | – |

**Key sentence:** *DNS finds the address. TCP builds a reliable pipe to that address and port.
TLS makes the pipe private and proves who is on the other end. HTTP is the conversation inside
the pipe.*

---

## 2. Layers (OSI vs TCP/IP) – where each piece sits

| OSI layer | TCP/IP layer | In our project |
|---|---|---|
| 7 Application | Application | **DNS** (dnsmasq, dig), **HTTP/1.1, HTTP/2**, REST API |
| 6 Presentation | Application | **TLS** encryption/encoding (often called "between transport and application") |
| 5 Session | Application | TLS session / handshake, session resumption |
| 4 Transport | Transport | **TCP** (HTTP/HTTPS, backends), **UDP** (DNS queries), **ports** 53, 80, 443, 3001, 3002 |
| 3 Network | Internet | **IPv4** addresses 192.168.x.x, routing via default gateway, **ICMP** (ping) |
| 2 Data link | Link | **Wi-Fi (802.11) / Ethernet**, **MAC addresses**, ARP |
| 1 Physical | Link | radio waves / cable |

Each layer **encapsulates** the one above. In Wireshark one packet shows
`Ethernet/802.11 → IP → TCP → TLS → (encrypted HTTP)`.

**Likely questions**
- *Where is TLS?* Above TCP and below HTTP. In OSI it fits layers 5–6. In TCP/IP it's part of the application layer.
- *Why does DNS use UDP?* A query and answer each fit in one small packet, so there's no handshake overhead. DNS falls back to TCP for large answers or zone transfers.
- *Which layer does ping work at?* Network layer (ICMP echo). That's why ping works even when DNS or a port is broken.

---

## 3. The LAN (Task A)

- **Private IPv4 address**: from the RFC 1918 ranges (10/8, 172.16/12, 192.168/16). These aren't routable on the internet; the router does NAT.
- **Subnet mask / prefix**: e.g. 255.255.255.0 = /24. The first 24 bits are the *network*, and the rest identify the *host*. Two hosts on the same subnet talk **directly** (Layer 2). Anything else goes to the **default gateway**.
- **Default gateway**: the router's IP. It's the exit for traffic that leaves the subnet.
- **MAC address**: the 48-bit Layer-2 address of the interface. Inside the LAN, frames are delivered by MAC. **ARP** maps IP → MAC (`arp -a` shows it).
- **Interface**: `en0` is usually Wi-Fi on a MacBook.
- **ping** = ICMP Echo Request/Reply. It proves IP-level reachability, nothing about ports or apps.

**Likely questions**
- *How does L1 reach L2?* Same subnet, so L1 ARPs for L2's MAC and sends the frame directly. The router isn't involved in routing.
- *Why might ping fail even on the same Wi-Fi?* AP client isolation, or the host firewall dropping ICMP.

---

## 4. DNS (Task B, Ext A, Ext B)

**What it is:** a distributed directory that turns names into records. Our **A records**
map `app.team67.test` and `api.team67.test` to the **edge** IP, never to a backend.

**Roles**
- **Stub resolver**: the OS part that asks questions (macOS mDNSResponder, with a cache).
- **Recursive resolver**: does the work of finding answers (normally your ISP / 1.1.1.1).
- **Authoritative server**: the source of truth for a zone. **Our dnsmasq is authoritative-like
  for `team67.test`** (`local=/team67.test/` = answer locally, never forward) and a **forwarder** for
  everything else (`server=1.1.1.1`), so internet names still work.

**Our dnsmasq config, line by line** (`templates/dnsmasq.conf.tmpl`)
- `listen-address=<LAN IP>` + `bind-interfaces`: answer only on this laptop's LAN address and loopback.
- `local=/team67.test/`: queries for our zone are never sent upstream. Unknown names in it get **NXDOMAIN**.
- `addn-hosts=records.hosts`: the records live in a hosts-style file, so we can change them live with **SIGHUP**.
- `local-ttl=30`: the TTL we hand out. dnsmasq's default is 0 (do not cache), which would make the TTL experiments impossible.
- `no-resolv` + `server=1.1.1.1`: ignore /etc/resolv.conf and forward non-project names to 1.1.1.1.
- `log-queries`: print every query, which is live evidence.

**Why `.test` and not `.local`?** `.test` is reserved (RFC 2606) for testing and never exists on the
internet. `.local` belongs to **multicast DNS** (Bonjour, RFC 6762). macOS sends `.local` lookups to
mDNS instead of our DNS server, which breaks things.

**TTL (Ext B):** every answer carries a Time-To-Live. Resolvers and OSes **cache** the answer for that
long. After we change the record, clients keep using the **old** IP until their cached copy expires. A
**flush** (`dscacheutil -flushcache` + `killall -HUP mDNSResponder`) throws the cache away immediately.
*Production:* before migrating a service, teams **lower the TTL** (e.g. 3600 → 60) a day ahead.
Then they change the record, so traffic moves within a minute. Afterwards they raise the TTL again.
Ext E shows exactly this.

**Backup resolver (Ext A):** a client with two DNS servers asks the first. If it doesn't answer
within a timeout, it asks the second. So a DNS outage costs a short delay, not a failure.
macOS may also spread queries across both. Both servers must hold **the same records**, which is
why we run the same records file on both.

**DNS failure vs application failure**
- DNS down → "Could not resolve host". Nothing else even starts, no TCP and no TLS.
- App down → the name resolves, TCP and TLS to the edge succeed, and nginx returns **502**.

**Likely questions**
- *Difference between DNS resolution and the TCP/HTTPS connection?* DNS only returns an **IP**. Nothing is
  "connected". The TCP connection to that IP:port is a completely separate step. Our failure demo "DNS
  points to the wrong IP" proves this: DNS succeeds, the connection fails.
- *Why do dig and the browser sometimes disagree?* `dig @server` asks the server directly, bypassing the
  OS cache. The browser goes through the OS resolver and its cache (and Chrome may use its own DoH).
- *Which port/protocol does DNS use?* UDP 53 (TCP 53 for large answers). The client uses a random source port.
- *What's a TTL of 0?* "Don't cache". Every request triggers a new query.
- *Cloud equivalent?* **AWS Route 53** (private hosted zone), Google Cloud DNS.

---

## 5. TCP, ports and sockets (Transport)

- **Port**: a 16-bit number that identifies an *application* on a host. Ours are DNS 53/UDP, HTTP 80,
  HTTPS 443, backends 3001/3002. Well-known ports are < 1024. **Ephemeral** client ports are
  49152–65535 on macOS, picked randomly per connection.
- **Socket pair (4-tuple)**: `(src IP, src port, dst IP, dst port)` uniquely identifies a TCP connection.
  Example: `192.168.1.10:52314 → 192.168.1.11:443`. Our nginx access log prints both ends.
- **Three-way handshake**: client `SYN (seq=x)` → server `SYN-ACK (seq=y, ack=x+1)` → client
  `ACK (ack=y+1)`. Only then can data (the TLS ClientHello) flow. This sets up initial sequence numbers
  on both sides.
- **Reliability**: every byte has a **sequence number**. The receiver sends cumulative **ACKs** for the next
  byte it expects. Missing data is retransmitted after a timeout or duplicate ACKs. Data is delivered in
  order. In Wireshark, "relative sequence numbers" start at 0 so this is easy to read.
- **Flow control**: the receiver advertises a **window** (how much more it can buffer) in every segment.
  The sender never has more unacknowledged data in flight than that. (Congestion control is a separate
  idea: it protects the *network* instead of the receiver.)
- **Connection refused vs timeout**:
  - Nothing listening on the port → the host replies **RST** → instant "connection refused"
    (our wrong-port demo).
  - Firewall **drops** the SYN → no reply at all → the client retries and then **times out**
    (our Ext C demo uses `block drop`).
- **Teardown**: FIN → ACK, FIN → ACK (or RST).

**Likely questions**
- *Why does ping work but the wrong port fails?* ping is ICMP at layer 3, so the host is up. The port is a
  layer-4 identifier, and nothing listens there.
- *Is our edge→backend connection the same TCP connection as client→edge?* No. A reverse proxy has **two
  separate TCP connections**. The backend sees the **edge's** IP as its peer (look at `seen_peer` in
  `/api/status`). The real client only arrives in `X-Forwarded-For`.

---

## 6. HTTPS and TLS (Task E)

**Why:** without TLS, anyone on the Wi-Fi can read and modify HTTP. TLS gives **confidentiality**
(encryption), **integrity** (tamper detection) and **authentication** (the certificate proves the server
is really app.team67.test).

**Certificates and trust – what `make-certs.sh` does**
1. Creates our own **Certificate Authority**: a key pair plus a self-signed CA certificate (`CA:TRUE`).
2. Creates a key pair for the server and a certificate for `app.team67.test` and `api.team67.test` in the
   **Subject Alternative Name** (SAN) field, **signed by our CA**. It has `extendedKeyUsage=serverAuth`
   and is valid ≤ 397 days, because macOS rejects TLS certs without SAN/EKU or with long validity.
3. `trust-ca.sh` adds the CA to the macOS **System keychain** as a trusted root.

How a client validates the certificate:
(1) the signature chains to a trusted root (our CA)
(2) today is within notBefore/notAfter
(3) the hostname typed is in the SAN list
(4) the server proves it owns the private key during the handshake.

If any check fails, you get a warning. That's why `-k` (skip validation) is forbidden: it would
accept *any* certificate, including an attacker's.

*Why our own CA and not a plain self-signed server cert?* It's the same model as the real web.
Browsers trust a few root CAs, and those sign server certs. We simply became our own root CA for our
private network (like a company's internal CA).

**TLS handshake**
- TLS 1.2: `ClientHello` (supported versions/ciphers, random, **SNI** = hostname) → `ServerHello`
  (chosen cipher, random) → `Certificate` → `ServerKeyExchange` (ECDHE public key) → `ServerHelloDone`
  → `ClientKeyExchange` → `ChangeCipherSpec` → `Finished` (both sides). Then encrypted
  `Application Data`. It takes 2 round trips.
- TLS 1.3 (curl/browsers use it by default): a **1 round trip** handshake. The key share is already in the
  ClientHello. Everything after `ServerHello`, **including the Certificate, is encrypted**. A
  `ChangeCipherSpec` is still sent only for middlebox compatibility. That's why
  `capture.sh --auto` makes **one TLS 1.2 connection** too: it lets you *show* the Certificate packet in
  Wireshark.
- **Key exchange** (ECDHE) creates a shared secret that never crosses the network, which gives
  *forward secrecy*. The certificate's key is only used to **sign** the handshake and prove identity.
- **SNI** (Server Name Indication) is visible in the ClientHello. It tells the server which certificate
  to present.

**TLS termination:** TLS ends at nginx. Edge→backend is plain HTTP inside our private LAN.
Pros: backends stay simple, the certificate lives in one place, and nginx can read the HTTP to route it.
Con: traffic inside the LAN is unencrypted. Production systems often re-encrypt it, which is
end-to-end TLS / mTLS.

**Likely questions**
- *Why is the HTTP payload unreadable in Wireshark?* It travels inside TLS records ("Application Data").
  Only the endpoints have the session keys.
- *What would the browser show if we used the IP instead of the name?* A certificate name mismatch. The IP
  isn't in the SAN. Our test showed curl: "no alternative certificate subject name matches".
- *What does HTTP/2 change?* Binary framing, many requests **multiplexed** on one TCP connection, and header
  compression (HPACK). It's negotiated during the TLS handshake via **ALPN** (look for `h2` in the
  ClientHello/ServerHello). **HTTP/3** runs over **QUIC (UDP)** instead of TCP, with TLS 1.3 built in
  (explanation-only in this project).

---

## 7. HTTP, REST and caching (Task C, Task F)

**REST endpoints** (`backend/server.py`): `GET /`, `GET /api/status`, `GET /api/data`. These are
resources identified by URLs and fetched with HTTP methods, with JSON responses. The app is simple on
purpose.

**Headers we use**
| Header | Set by | Meaning |
|---|---|---|
| `Host` | client | which site, since one IP can host many names (nginx `server_name`) |
| `X-Backend: A/B` | backend | which backend served it, for the LB demo |
| `X-Edge` | nginx | which edge served it (primary vs standby, Ext E) |
| `X-Forwarded-For` | nginx | the original client IP, because the backend only sees the edge |
| `Cache-Control: no-store` | backend | `/api/status` must never be cached, so we always see fresh LB results |
| `Cache-Control: public, max-age=60` | backend | `/api/data` may be reused for 60 s without asking |
| `ETag: "991d…"` | backend | a version fingerprint of `/api/data` (hash of the body) |
| `If-None-Match: "991d…"` | client | "send it only if it changed" |

**Status codes you'll show:** 200 OK, 301 redirect (HTTP → HTTPS), 304 Not Modified, 404 Not Found,
**502 Bad Gateway** (proxy couldn't reach any upstream).

**Three kinds of cache behaviour (Task F)**
1. **Fresh hit:** the cached copy is younger than `max-age`. The browser uses it **without sending any
   request**. DevTools shows "(disk cache)" or "(memory cache)".
2. **Conditional request (revalidation):** the copy is stale (or the user pressed reload). The browser sends
   `If-None-Match: <etag>`. If unchanged, the server returns **304 with no body**. You save bandwidth but
   still pay one round trip. (Our test: 496 bytes vs 0 bytes.)
3. **Full request:** no cached copy or the ETag doesn't match → **200** with the full body.

Our ETag is computed from the content, which is identical on A and B. So a 304 works whichever backend
the load balancer picks. **Interview point:** if each backend generated its own ETag, revalidation would
randomly fail behind a load balancer.

**CDN connection:** a CDN (CloudFront, Cloudflare) is a shared cache near users that obeys these same
headers. Our edge is the "CDN edge node" role.

---

## 8. Reverse proxy and load balancing (Task D, Ext D)

**Reverse proxy:** the single public entry point. Clients only know `app.team67.test` → the edge IP.
Backends can change, scale or fail without clients knowing. That's why the client never needs backend
IPs, and also why we can firewall them away (Ext C).

**Round robin:** each new request goes to the next server in the list: A, B, A, B. That's nginx's
default. **least_conn** instead sends each request to the server with the fewest active connections,
which is better when request times vary. (You could also use weights, or ip_hash for stickiness.)

**Health checking (Ext D)** – our config:
```
server A max_fails=1 fail_timeout=10s;
proxy_next_upstream error timeout http_502 http_503;
proxy_connect_timeout 2s;
```
Open-source nginx uses **passive** health checks. When a request to A fails (connection refused or
timeout), nginx (1) **retries the same request on B**, so the client still gets 200, and (2) marks A
"down" for 10 s. After that it tries A again. When A is back, round robin resumes. Commercial
nginx Plus and cloud LBs use **active** checks: they probe `/health` every few seconds.

**Single point of failure (SPOF):** the edge nginx is the only entry point. If L2 dies, everything
dies, and in our 3-laptop layout Backend B dies with it, since it also runs on L2. Backend A on L3 is
already redundant: if L3 dies, B keeps serving. With 4 members only the edge would remain a SPOF. To remove the edge SPOF:
- run **two edges** with a **floating virtual IP** (VRRP with keepalived: the standby takes over the IP in about 1 s)
- or publish **multiple A records / DNS failover with health checks** (Route 53 health checks)
- or use a managed, internally redundant load balancer (AWS ALB/NLB, GCP LB)
- or use **anycast**

Ext E shows the manual, DNS-based version of this, which is limited by TTL.

**Cloud mapping:** our edge = **AWS ALB / GCP HTTPS Load Balancer** (TLS termination + LB + health
checks). Backends = EC2 instances in a target group. dnsmasq = **Route 53 private hosted zone**.
Firewall rules = **security groups** (only the LB's security group may reach the instances).

---

## 9. Firewall / service isolation (Ext C)

macOS has **pf** (packet filter, from OpenBSD). It's a **stateful** firewall: once a connection is
allowed, its reply packets are allowed automatically (`keep state`). Our rules (`build/pf/cnproject.rules`):
```
pass  in quick proto tcp from { EDGE_IP, 127.0.0.1 } to any port { 3001, 3002 }
block drop in quick proto tcp from any to any port { 3001, 3002 }
```
`quick` means the first match wins. Only the edge may open connections to the backend ports. Anyone
else's SYN is silently **dropped**, so they get a timeout. (`block return` would send an RST instead,
giving an immediate "refused"; both are valid.) The rules are loaded into a separate **anchor**
(`com.apple/cnproject`), so the system's own firewall config is untouched, and rollback is a single
flush (`firewall-off.sh`).

**Principle:** *defence in depth / least privilege*. Even if someone learns the backend IP, they can't
skip the edge. That means they can't bypass TLS, logging, rate limits and so on.

---

## 10. Systematic troubleshooting (Ext F) – work bottom-up, one layer at a time

| Step | Question | Command | If it fails → |
|---|---|---|---|
| 0 | Am I on the LAN? | `ipconfig getifaddr en0`, `ping <edge-IP>` | Wi-Fi / IP / subnet problem (layers 1-3) |
| 1 | Does the name resolve? | `dig app.team67.test`, `dig @<dns-IP> app.team67.test` | DNS: server down, wrong record, client using wrong resolver, stale cache |
| 2 | Is the right IP returned? | compare with team.env EDGE_IP | wrong record → `dns-point-app.sh edge`, flush |
| 3 | Can I open TCP to the port? | `nc -vz app.team67.test 443` | refused = nothing listening (nginx down / wrong port). Timeout = firewall |
| 4 | Does TLS succeed? | `curl -v https://app.team67.test` / `openssl s_client -connect app.team67.test:443 -servername app.team67.test` | cert expired / wrong name / untrusted CA / wrong cert path |
| 5 | Does HTTP succeed? | `curl -i https://app.team67.test/api/status` | 502 = edge can't reach backends. 404 = wrong path or server_name |
| 6 | Backends themselves? | on L2: `curl -i http://<L3-IP>:3001/api/status` and `http://<L2-IP>:3002/api/status` | backend stopped / wrong port / firewall |

Typical injected faults: dnsmasq stopped, a record changed to a wrong IP, the client's DNS server changed,
nginx stopped, an nginx upstream port changed, a backend stopped, the cert renamed or expired, a firewall
rule left on, the wrong port in a URL. **Say out loud** which layer you're testing and why. Partial credit
goes to the method.

---

## 11. Rapid-fire viva questions

1. **What happens when you type the URL?** See §1. DNS → TCP → TLS → HTTP → proxy → backend → back.
2. **Why does the client never need the backend IPs?** DNS points to the edge. The edge holds the upstream list.
3. **Port of DNS / HTTPS / our backends?** 53 UDP / 443 TCP / 3001, 3002 TCP.
4. **What's in a DNS answer?** Name, TTL, class IN, type A, IPv4 address.
5. **What does TTL 30 mean?** Caches may reuse the answer for 30 s.
6. **How did you make the browser trust your cert?** Our own CA, its cert added to the System keychain as a trusted root, and the server cert signed by it with the right SAN.
7. **Why not use `curl -k`?** It disables authentication, so a MITM would succeed.
8. **What's TLS termination?** Decrypting at the edge. Inside the LAN it's plain HTTP.
9. **What's SNI?** The hostname in the ClientHello, used to pick the certificate.
10. **What's the difference between 200 and 304?** 304 = "your cached copy is still valid", with no body.
11. **What causes a 502?** The proxy works, but no upstream is reachable.
12. **Round robin vs least_conn?** Rotation vs fewest active connections.
13. **How does nginx detect a dead backend?** Passive checks: a failed request makes it retry the other backend and mark the dead one down for `fail_timeout`.
14. **What's still a SPOF?** The edge, i.e. L2 (which also hosts Backend B in our 3-laptop layout). Fixes: VRRP floating IP, multiple edges + DNS health checks, managed LB.
15. **Why `.test` and not `.local`?** `.local` is mDNS/Bonjour on macOS.
16. **What does the 3-way handshake achieve?** Both sides agree on initial sequence numbers and confirm two-way reachability before sending data.
17. **Refused vs timed out?** RST from the host (no listener) vs no answer (dropped by a firewall / host down).
18. **Why do you see the Certificate packet in TLS 1.2 but not 1.3?** TLS 1.3 encrypts everything after ServerHello.
19. **HTTP/2 vs HTTP/1.1?** Multiplexing, binary frames, header compression. Same semantics, negotiated with ALPN.
20. **How would you migrate the edge with minimum disruption?** Lower the TTL in advance, bring up the standby, switch the DNS record, wait for the old TTL to expire, then retire the old edge (Ext E).
