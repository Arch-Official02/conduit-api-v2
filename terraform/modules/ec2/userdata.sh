#!/bin/bash
set -e

# ── system update + docker install ───────────────────────────────────────────
yum update -y
yum install -y docker aws-cli
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# ── docker compose install ────────────────────────────────────────────────────
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# ── ecr login for root ────────────────────────────────────────────────────────
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repo_url}

# ── ecr login for ec2-user ────────────────────────────────────────────────────
mkdir -p /home/ec2-user/.docker
chown -R ec2-user:ec2-user /home/ec2-user/.docker
sudo -u ec2-user aws ecr get-login-password --region ${aws_region} | sudo -u ec2-user docker login --username AWS --password-stdin ${ecr_repo_url}

# ── create app directory and docker-compose file ──────────────────────────────
mkdir -p /home/ec2-user/app

cat > /home/ec2-user/app/docker-compose.yml << 'COMPOSE'
services:
  mongo:
    image: public.ecr.aws/docker/library/mongo:4.4
    restart: unless-stopped
    volumes:
      - mongo-data:/data/db
    networks:
      - app-network

  app:
    image: ${ecr_repo_url}:latest
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - MONGODB_URI=mongodb://mongo:27017/conduit
      - PORT=3000
      - SECRET=${secret}
    depends_on:
      - mongo
    command: sh -c "sleep 5 && node app.js"
    networks:
      - app-network

volumes:
  mongo-data:

networks:
  app-network:
COMPOSE

chown -R ec2-user:ec2-user /home/ec2-user/app

# ── ecr login refresh script ──────────────────────────────────────────────────
cat > /usr/local/bin/ecr-login.sh << 'ECRLOGIN'
#!/bin/bash
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repo_url}
mkdir -p /home/ec2-user/.docker
chown -R ec2-user:ec2-user /home/ec2-user/.docker
sudo -u ec2-user aws ecr get-login-password --region ${aws_region} | sudo -u ec2-user docker login --username AWS --password-stdin ${ecr_repo_url}
ECRLOGIN
chmod +x /usr/local/bin/ecr-login.sh

# ── systemd service for ecr login ─────────────────────────────────────────────
cat > /etc/systemd/system/ecr-login.service << 'ECRSERVICE'
[Unit]
Description=ECR Login
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ecr-login.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
ECRSERVICE

# ── systemd service for conduit app ───────────────────────────────────────────
cat > /etc/systemd/system/conduit.service << 'CONDUITSERVICE'
[Unit]
Description=Conduit API
After=docker.service ecr-login.service
Requires=docker.service ecr-login.service

[Service]
WorkingDirectory=/home/ec2-user/app
ExecStart=/usr/local/bin/docker-compose up
ExecStop=/usr/local/bin/docker-compose down
Restart=always
RestartSec=15
User=ec2-user

[Install]
WantedBy=multi-user.target
CONDUITSERVICE

# ── enable and start all services ─────────────────────────────────────────────
systemctl daemon-reload
systemctl enable ecr-login
systemctl enable conduit
systemctl start ecr-login
systemctl start conduit

# ── monitoring stack ──────────────────────────────────────────────────────────
mkdir -p /home/ec2-user/monitoring

cat > /home/ec2-user/monitoring/prometheus.yml << 'PROM'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'conduit-api'
    static_configs:
      - targets: ['app-app-1:3000']
    metrics_path: '/metrics'
PROM

cat > /home/ec2-user/monitoring/docker-compose.yml << 'MONITORING'
services:

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    networks:
      - monitoring-network
      - app_app-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=archy
      - GF_SECURITY_ADMIN_PASSWORD=conduit222
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - monitoring-network

volumes:
  prometheus-data:
  grafana-data:

networks:
  monitoring-network:
  app_app-network:
    external: true
MONITORING

chown -R ec2-user:ec2-user /home/ec2-user/monitoring

# ── monitoring systemd service ────────────────────────────────────────────────
cat > /etc/systemd/system/monitoring.service << 'SERVICE'
[Unit]
Description=Monitoring Stack (Prometheus + Grafana)
Requires=docker.service conduit.service
After=docker.service conduit.service

[Service]
WorkingDirectory=/home/ec2-user/monitoring
ExecStart=/usr/local/bin/docker-compose up
ExecStop=/usr/local/bin/docker-compose down
Restart=always
RestartSec=15
User=ec2-user

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable monitoring
systemctl start monitoring