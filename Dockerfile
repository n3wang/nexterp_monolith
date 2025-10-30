FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN useradd -ms /bin/bash frappe

RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3.11-venv \
    python3-pip python3-setuptools \
    git curl sudo redis-server \
    libmysqlclient-dev default-mysql-client \
    xvfb libfontconfig wkhtmltopdf \
    cron && \
    apt-get clean

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn

RUN pip3 install frappe-bench

COPY --chmod=755 entrypoint.sh /entrypoint.sh
RUN ls -la /entrypoint.sh

# Expose port
EXPOSE 8080

USER frappe
WORKDIR /home/frappe

CMD ["/entrypoint.sh"]
