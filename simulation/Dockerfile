# Use multi-arch for compatibility
FROM debian:bookworm-slim

# Simulate Raspberry Pi OS environment
LABEL description="Crooked Sentry Raspberry Pi Simulation"
LABEL architecture="multi-arch"
LABEL base="debian:bookworm-slim"

# Install base packages that would be on Raspberry Pi OS
RUN apt-get update && apt-get install -y \
    # Base system packages
    systemd systemd-sysv \
    dbus dbus-user-session \
    # Network and SSH 
    openssh-server openssh-client \
    iproute2 iputils-ping \
    net-tools curl wget \
    # Development tools
    git vim nano \
    # Python for Ansible and Frigate simulation
    python3 python3-pip python3-venv \
    python3-pil \
    # Docker prerequisites  
    ca-certificates curl gnupg lsb-release \
    apt-transport-https software-properties-common \
    # WireGuard tools
    wireguard-tools qrencode \
    # DNS tools
    dnsmasq bind9-dnsutils \
    # Process management
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Create pi user (like Raspberry Pi OS)
RUN useradd -m -s /bin/bash pi && \
    echo 'pi:raspberry' | chpasswd && \
    usermod -aG sudo pi && \
    # Allow sudo without password (like fresh Pi)
    echo 'pi ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# SSH setup for Ansible connectivity
RUN mkdir -p /home/pi/.ssh && \
    ssh-keygen -A && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Install Docker CE (detect architecture automatically)
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    ARCH=$(dpkg --print-architecture) && \
    echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin && \
    usermod -aG docker pi && \
    rm -rf /var/lib/apt/lists/*

# Install Docker Compose separately for compatibility
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then COMPOSE_ARCH="x86_64"; else COMPOSE_ARCH="aarch64"; fi && \
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# Create directory structure like real Pi deployment
RUN mkdir -p /opt/crooked-sentry/{config,data} && \
    mkdir -p /etc/frigate /media/frigate && \
    mkdir -p /var/www/{info,wireguard} && \
    chown -R pi:pi /opt/crooked-sentry

# Copy simulation configs and scripts
COPY simulation/configs/ /opt/crooked-sentry/config/
COPY simulation/scripts/ /usr/local/bin/
COPY simulation/scripts/frigate-sim.py /tmp/frigate-sim.py
COPY config/www-info/ /var/www/info/

# Install nginx for web server
RUN apt-get update && apt-get install -y nginx && \
    rm -rf /var/lib/apt/lists/* && \
    cp /opt/crooked-sentry/config/nginx.conf /etc/nginx/sites-available/default

# Supervisor configuration for multi-service simulation
COPY simulation/supervisor.conf /etc/supervisor/conf.d/crooked-sentry.conf

# Create systemd-like service management script and set permissions
RUN chmod +x /usr/local/bin/sim-* && \
    mkdir -p /var/log/supervisor

# Expose ports for testing
EXPOSE 22 80 5000 51820/udp 8554 8555

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Initialize simulation environment
WORKDIR /opt/crooked-sentry

# Start supervisor to manage services (must run as root)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n"]