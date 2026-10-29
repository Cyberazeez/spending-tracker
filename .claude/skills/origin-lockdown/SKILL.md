---
name: origin-lockdown
description: Check and fix origin IP exposure for a site behind Cloudflare (or any CDN/WAF). Use when the user mentions Cloudflare setup, WAF, DDoS protection, hiding the origin server, or deploying a site behind a proxy.
---

# Origin lockdown

A CDN/WAF only protects you if attackers can't reach the origin directly. Work through this, report what's done and what's missing, and only change DNS, firewall or Cloudflare settings after the user confirms.

## 1. Find leaks
- **DNS history**: if the domain ever pointed straight at the origin IP, assume it's public (SecurityTrails, ViewDNS). If so, recommend a new origin IP.
- **Grey-clouded records**: list every DNS record. Any A/AAAA/CNAME to the origin that isn't proxied (mail, ftp, cpanel, dev, staging, direct) leaks the IP.
- **Certificates**: check crt.sh for subdomains that might resolve to the origin.
- **Email headers**: if the server sends mail itself, the `Received:` header shows its IP. Send through a mail provider (Resend, SES, Postmark, Google Workspace) instead.
- **App leaks**: error pages, `X-Powered-By`/debug headers, outbound requests the app makes to user-supplied URLs (SSRF/webhooks), and hardcoded IPs in the repo.

## 2. Lock the origin (pick the strongest that fits)
1. **Cloudflare Tunnel** (`cloudflared`): no open inbound ports at all. Best option for a VPS.
2. **Firewall allowlist**: allow 80/443 only from Cloudflare's IP ranges (cloudflare.com/ips), deny everything else. Keep SSH restricted to your IP or a tunnel.
3. **Authenticated Origin Pulls** (mTLS) so the origin only accepts Cloudflare's client cert.
- On managed hosts (Vercel, Sevalla, Netlify) check whether the platform URL (`*.vercel.app` etc.) bypasses Cloudflare, and disable or protect it.

## 3. Cloudflare settings
- SSL/TLS mode **Full (strict)** with an origin certificate.
- WAF managed rules on, rate limiting on login/checkout/API routes, bot protection, Always Use HTTPS, HSTS.

## 4. Verify
- `curl -I https://<origin-ip> -H "Host: <domain>"` from outside should fail or time out.
- Response headers on the real domain should show `cf-ray`.
