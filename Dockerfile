FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# ─── System packages ─────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3.11-venv python3-pip python3-setuptools \
    git curl sudo \
    default-mysql-client libmysqlclient-dev \
    redis-tools redis-server \
    xvfb libfontconfig wkhtmltopdf \
    cron && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Node 18 + yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# frappe user with sudo for volume ownership fixes at runtime
RUN useradd -ms /bin/bash frappe && \
    echo 'frappe ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# frappe-bench + uv (faster pip)
RUN pip3 install frappe-bench uv

# ─── Bench init at IMAGE BUILD TIME — cached in Docker layer ─────────────────
# This is the expensive step (clones frappe, runs yarn, pip-installs frappe).
# It only re-runs when this layer or earlier layers change.
USER frappe
WORKDIR /home/frappe

RUN bench init frappe-bench \
    --frappe-branch version-15 \
    --python python3.11

WORKDIR /home/frappe/frappe-bench

# Remove local redis entries from Procfile — we use the external Redis service
RUN sed -i '/redis/Id' Procfile 2>/dev/null || true

# ─── Pre-install custom ERPNext app ──────────────────────────────────────────
ARG ERPNEXT_REPO=https://github.com/quanteonlab/erp15.git
ARG ERPNEXT_BRANCH=main

# Cache-bust only when the remote HEAD changes
ADD https://api.github.com/repos/quanteonlab/erp15/git/refs/heads/${ERPNEXT_BRANCH} /tmp/erp15_head.json

RUN bench get-app erpnext ${ERPNEXT_REPO} --branch ${ERPNEXT_BRANCH}
RUN bench get-app ecommerce_integrations https://github.com/frappe/ecommerce_integrations.git --branch develop

# Build JS/CSS assets (cached here — not rebuilt on every container start)
RUN bench build

COPY --chown=frappe:frappe entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
