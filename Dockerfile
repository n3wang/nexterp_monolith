FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Create frappe user
RUN useradd -ms /bin/bash frappe

# System dependencies
RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3.11-venv \
    python3-pip python3-setuptools \
    git curl sudo \
    default-mysql-client libmysqlclient-dev \
    xvfb libfontconfig wkhtmltopdf \
    cron && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Node 18 + yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# frappe-bench CLI
RUN pip3 install frappe-bench

# Grant sudo to frappe user (needed during bench init)
RUN echo 'frappe ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8000

USER frappe
WORKDIR /home/frappe

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
