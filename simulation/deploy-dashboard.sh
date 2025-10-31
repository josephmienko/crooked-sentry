#!/bin/bash
# Deploy Flutter dashboard to simulation

echo "=== DEPLOYING FLUTTER DASHBOARD TO SIMULATION ==="

# Build Flutter for web
echo "Building Flutter dashboard..."
cd /Users/mienko/crooked-sentry/home_dashboard
make flutter-build

# Copy built files to simulation
echo "Copying Flutter build to simulation..."
docker exec crooked-sentry-pi-sim mkdir -p /var/www/dashboard
docker cp build/web/. crooked-sentry-pi-sim:/var/www/dashboard/

# Update nginx config to serve dashboard
echo "Configuring nginx for dashboard..."
docker exec crooked-sentry-pi-sim bash -c 'cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/info;
    index index.html;
    server_name _;
    
    # Main info page
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Flutter dashboard (for authenticated users)
    location /dashboard/ {
        alias /var/www/dashboard/;
        try_files \$uri \$uri/ /dashboard/index.html;
        
        # Add cache headers for Flutter assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # WireGuard config endpoint  
    location /household.conf {
        alias /var/www/info/household.conf;
        add_header Content-Type text/plain;
    }
    
    # Network detection endpoint
    location /whoami {
        add_header Content-Type text/plain;
        return 200 "network: lan\nip: \$remote_addr\n";
    }
    
    # Frigate proxy
    location /frigate/ {
        proxy_pass http://localhost:5000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF'

# Reload nginx
docker exec crooked-sentry-pi-sim nginx -s reload

echo ""
echo "✅ Flutter dashboard deployed!"
echo "   Dashboard: http://localhost:8080/dashboard/"
echo "   Frigate: http://localhost:8080/frigate/"
echo "   Network API: http://localhost:8080/whoami"