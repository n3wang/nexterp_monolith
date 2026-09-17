# Architecture Overview

## Components

### 1. React Frontend (ecommerce / POS storefront)

**Repo:** `erpnext-ecommerce` (this monorepo)

- Deployed as Docker (`react-blue` / `react-green` blue-green).
- Public host today: `shop.l.l0l.in` (Caddy → active React slot).
- Server-side proxies (`/api/pm/*`, etc.) call ERPNext at `ERPNEXT_URL` (Docker: `http://erpnext:8000`).
- Browser does not call MariaDB; only HTTPS to shop (and optionally erp desk).

### 2. Frappe Bench / ERPNext

**Repo:** `apps/erpnext` inside the bench; image built from `nexterp_monolith/`.

- Process: gunicorn + workers in the `erpnext` container.
- Sites live on volume `frappe_data` → `/home/frappe/frappe-bench/sites`.
- Public host today: `erp.l.l0l.in`.

### 3. Shared data plane

| Service | Role |
|---------|------|
| **MariaDB 10.6** | One server; **one database per Frappe site** |
| **Redis** | Cache + queues (logical DB index can isolate dev) |
| **Caddy** | TLS + host routing (`/root/docker/caddy/Caddyfile`) |

Dev profile already mirrors multi-DB on one MariaDB: `erpnext-dev` → `SITE_NAME=dev.local`, `DB_NAME=erpnext_dev`.

---

## Connection map (current single-tenant)

```text
Browser
  │
  ├─ https://shop.l.l0l.in  →  Caddy  →  react-blue|green:3000
  │                                      │
  │                                      └─ http://erpnext:8000  (ERPNEXT_URL)
  │
  └─ https://erp.l.l0l.in   →  Caddy  →  erpnext:8000
                                              │
                              MariaDB ◄───────┘   Redis
```

---

## Multi-tenant direction (cheap / shared hypervisor)

**Plan:** [`local_docs/proposals/i037_multi_tenant_subdomain_shared_mariadb.md`](../local_docs/proposals/i037_multi_tenant_subdomain_shared_mariadb.md)

- Hosts: `a.shop.l.l0l.in`, `b.shop.l.l0l.in` (wildcard DNS + Caddy).
- Same MariaDB **instance**, different **databases** (native Frappe sites).
- Same ERPNext + React containers; provision tenant = `bench new-site` + seed, not a new VPS.

Orthogonal: in-app **multi-company** (several CUIT inside one site) ≠ multi-tenant isolation.

---

## Deploy

```bash
make deploy-bg          # blue/green React + rolling erpnext
# After DocType changes:
docker compose -f nexterp_monolith/docker-compose.yml exec erpnext \
  bench --site site.local migrate
```

See root `CLAUDE.md` / `README.md` for day-to-day commands.

---

## Note on secrets

Do **not** store SSH private keys, DB passwords, or API secrets in this file. Use env files / a secrets manager on the host only.
