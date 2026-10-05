# Phase 1 – required failure demonstrations (Team 67)

Captured 2026-10-05 on Laptop 1 (Priyansh, 10.7.19.6) as the client.
Edge = Laptop 2 (Bhavay, 10.7.27.44) · Backend A = Laptop 3 (Nishant, 10.7.23.55:3001) · Backend B = Laptop 2 (:3002).
Each section: what we broke, the exact commands and output, what it proves, how we restored it.

---

## H1 – Wrong DNS server configured on the client

**Broke it:** `./scripts/set-client-dns.sh --wrong` (Mac's DNS set to 192.0.2.53, a TEST-NET address where no DNS server exists)

```
$ ping -c 2 app.team67.test
ping: cannot resolve app.team67.test: Unknown host

$ ping -c 2 10.7.27.44
PING 10.7.27.44 (10.7.27.44): 56 data bytes
64 bytes from 10.7.27.44: icmp_seq=0 ttl=64 time=124.554 ms
64 bytes from 10.7.27.44: icmp_seq=1 ttl=64 time=56.436 ms

--- 10.7.27.44 ping statistics ---
2 packets transmitted, 2 packets received, 0.0% packet loss
```

**Proves:** name lookup fails although the machines still have direct IP connectivity → the DNS (application layer) and IP (network layer) are independent.

**Restored:** `./scripts/set-client-dns.sh && dig app.team67.test +short` → `10.7.27.44`

---

## H2 – DNS record points to a wrong IP address

**Broke it:** `./scripts/dns-point-app.sh 10.7.23.55 && ./scripts/flush-dns.sh`
(app.team67.test pointed at Nishant's laptop, which runs no web server on 443)

```
==> app.team67.test: 10.7.27.44  ->  10.7.23.55   (records file updated)
  [PASS] dnsmasq (pid 36987) reloaded

$ dig app.team67.test +short
10.7.23.55

$ curl https://app.team67.test/api/status
curl: (7) Failed to connect to app.team67.test port 443 after 1014 ms: Couldn't connect to server
```

**Proves:** DNS resolution *succeeds* but returns the wrong destination; the failure then happens at TCP. DNS is a directory, not a connection – it does not check that the service exists.

**Restored:** `./scripts/dns-point-app.sh edge && ./scripts/flush-dns.sh` → `dig` returns `10.7.27.44` again.

---

## H3 – One backend is stopped

**Broke it:** Ctrl+C on Backend A (Nishant's laptop).

```
$ ./scripts/test-lb.sh 6
==> 6 requests to https://app.team67.test/api/status
    #1   HTTP 200  X-Backend: B   X-Edge: primary (10.7.27.44)
    #2   HTTP 200  X-Backend: B   X-Edge: primary (10.7.27.44)
    #3   HTTP 200  X-Backend: B   X-Edge: primary (10.7.27.44)
    #4   HTTP 200  X-Backend: B   X-Edge: primary (10.7.27.44)
    #5   HTTP 200  X-Backend: B   X-Edge: primary (10.7.27.44)
    #6   HTTP 200  X-Backend: B   X-Edge: primary (10.7.27.44)

    Backend A: 0   Backend B: 6   failed: 0
```

**Proves:** the edge keeps serving through the remaining backend with zero client errors.
nginx config: `max_fails=1 fail_timeout=10s` + `proxy_next_upstream error timeout http_502 http_503` – a request that hits the dead backend is retried on the other one, and the dead backend is skipped for 10 s.

**Restored:** `./scripts/start-backend.sh A` → round robin A/B resumed (verify.sh: `sequence of backends: ABABAB`).

---

## H4 – Both backends are stopped

**Broke it:** Ctrl+C on Backend A (Nishant) and Backend B (Bhavay).

```
$ curl -i https://app.team67.test/api/status
HTTP/2 502
server: nginx/1.31.6
date: Mon, 05 Oct 2026 11:22:17 GMT
content-type: text/html
content-length: 157
x-edge: primary (10.7.27.44)

<html>
<head><title>502 Bad Gateway</title></head>
<body>
<center><h1>502 Bad Gateway</h1></center>
<hr><center>nginx/1.31.6</center>
</body>
</html>
```

**Proves:** DNS, TCP, TLS (HTTP/2 over TLS) and the edge itself still work – the response comes from nginx (`server: nginx`, `x-edge`). Only the upstream is unreachable → 502. This shows exactly where the edge ends and the backends begin.

**Restored:** both backends restarted.

---

## H5 – Wrong destination port on the client

```
$ ping -c 2 app.team67.test
PING app.team67.test (10.7.27.44): 56 data bytes
64 bytes from 10.7.27.44: icmp_seq=0 ttl=64 time=39.142 ms
64 bytes from 10.7.27.44: icmp_seq=1 ttl=64 time=36.129 ms

--- app.team67.test ping statistics ---
2 packets transmitted, 2 packets received, 0.0% packet loss

$ curl https://app.team67.test:8444/api/status
curl: (7) Failed to connect to app.team67.test port 8444 after 1133 ms: Couldn't connect to server
```

**Proves:** the host is reachable (name resolves, ICMP works) but nothing listens on port 8444, so the TCP connection fails. The IP address identifies the machine; the port identifies the service on it.

---

## After all demos

```
$ ./scripts/verify.sh
  ...
  [PASS] backend A at 10.7.23.55:3001 answers with X-Backend: A
  [PASS] backend B at 10.7.27.44:3002 answers with X-Backend: B
  [PASS] https://app.team67.test -> HTTP 200, HTTP/2, certificate verified, connected to 10.7.27.44
    sequence of backends: ABABAB
  [PASS] both backends served requests
  [PASS] conditional request -> 304 Not Modified

  [PASS] PHASE 1 GATE PASSED
```
