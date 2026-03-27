
# Architecture Overview

## Components




### 1. React Frontend (ecommerce storefront)
**Repo:** https://github.com/n3wang/erpnext-ecommerce.git

- Deploy separately as a Node.js app (e.g. via CapRover, Vercel, or `pm2`).
- Installed at the server root or a subdomain: `shop.yourdomain.com`
- Connects to: the Frappe/ERPNext backend via the ERPNext REST API and Webshop endpoints.
- Set `NEXT_PUBLIC_FRAPPE_URL=https://erp.yourdomain.com` in its `.env`.

---

### 2. Frappe Bench (server runtime + bench config)
**Repo:** https://github.com/n3wang/frappe-bench-custom-test.git

- Cloned on the server at `~/frappe-bench-custom-test/`.
- This is the bench environment: it contains `apps/`, `sites/`, `config/`, `env/`.
- Does NOT include app source code directly (apps are git submodules or separate clones under `apps/`).
- The bench manages the Frappe/ERPNext process workers, Redis, MariaDB connections, and site configs.
- Run with `bench start` (dev) or `bench setup production` (prod via nginx + supervisor).

---

### 3. ERPNext Custom App (backend business logic)
**Repo:** https://github.com/quanteonlab/erp15.git

- Cloned into `apps/erpnext/` inside the bench:
  ```
  cd ~/frappe-bench-custom-test/apps/erpnext
  git remote -v   # should point to quanteonlab/erp15
  ```
- This is the actual ERPNext application code (Python/JS), customized for this project.
- Installed into a site with:
  ```
  bench --site dev_site_a install-app erpnext
  ```
- Connects to: MariaDB (via bench site config), Redis (queue/cache), and exposes REST API consumed by the React frontend.

---

## Connection Map

```
React App (shop.yourdomain.com)
    |
    | HTTP REST / Webshop API
    v
Frappe Bench  (erp.yourdomain.com)
    |-- nginx (routes to gunicorn)
    |-- frappe workers (Python)
    |-- ERPNext app  <-- source: quanteonlab/erp15
    |-- MariaDB (site database)
    |-- Redis   (cache + queue)
```


```
ssh-keygen -t ed25519 -C "wangnelson2@gmail.com"

```


```
cd apps/erpnext
```

```
newang@DESKTOP-KLQB96D:~/frappe-bench-custom-test/apps$ cd erpnext/
newang@DESKTOP-KLQB96D:~/frappe-bench-custom-test/apps/erpnext$ git origin -v
git: 'origin' is not a git command. See 'git --help'.
newang@DESKTOP-KLQB96D:~/frappe-bench-custom-test/apps/erpnext$ git remote -v
origin  https://github.com/quanteonlab/erp15.git (fetch)
origin  https://github.com/quanteonlab/erp15.git (push)
```


(env) newang@DESKTOP-KLQB96D:~/frappe-bench-custom-test$ cat /home/newang/.ssh/id_ed25519
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABCsPQ8lsQ
KX5NrgH7xy8Q5CAAAAEAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAINQbPZ+nxZJYSafw
6kq8lBL1nW6oHEj91vZpONHY7Mq2AAAAoC0WYrRRlftkKI4Sp/ntO0Q1YDFY7lGJgZYkNc
wulBGXwEfOvi6dbv8rilW5v/wsFf2s24XNTQxfmg/CJ25S9ienSk8hk2+E/BRTIW/mCb6w
zUulWvOIyKOiliGogRnu00cm/xWNMQr4IAUh3rNDIeFbbIC7TPgsS8TdISFUhmKTWVYp7f
OtYfnQ7KSaFEdvNjxxWivJrlmNQaGCaeMF6Ow=
-----END OPENSSH PRIVATE KEY-----
```


(env) newang@DESKTOP-KLQB96D:~/frappe-bench-custom-test$ cat ~/.ssh/id_ed25519.pub

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQbPZ+nxZJYSafw6kq8lBL1nW6oHEj91vZpONHY7Mq2 wangnelson2@gmail.com
```


