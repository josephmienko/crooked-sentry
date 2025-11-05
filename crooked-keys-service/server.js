const express = require('express');
const crypto = require('crypto');
const fs = require('fs').promises;
const path = require('path');
const { execSync } = require('child_process');
const QRCode = require('qrcode');
const winston = require('winston');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const app = express();
const PORT = process.env.PORT || 3001;

// Logging setup
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: '/var/log/crooked-keys/error.log', level: 'error' }),
    new winston.transports.File({ filename: '/var/log/crooked-keys/combined.log' }),
    new winston.transports.Console({ format: winston.format.simple() })
  ]
});

// Security middleware
app.use(helmet());
app.use(express.json({ limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // limit each IP to 10 requests per windowMs
  message: { error: 'Too many requests, try again later' }
});

const keyExchangeLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3, // limit each IP to 3 VPN configs per hour
  message: { error: 'Too many VPN config requests, try again in an hour' }
});

app.use('/api/crooked-keys/', limiter);

// Configuration
const CONFIG = {
  WIREGUARD_SERVER_IP: process.env.WG_SERVER_IP || '192.168.0.200',
  WIREGUARD_PORT: process.env.WG_PORT || '51820',
  VPN_NETWORK: process.env.VPN_NETWORK || '10.8.0.0/24',
  SERVER_PUBLIC_KEY_PATH: '/etc/wireguard/server_public.key',
  SERVER_CONFIG_PATH: '/etc/wireguard/wg0.conf',
  CLIENT_DATA_PATH: '/opt/crooked-keys/data/clients.json',
  DNS_SERVERS: '8.8.8.8, 8.8.4.4'
};

// Utility functions
function generateWireGuardKeys() {
  try {
    const privateKey = execSync('wg genkey', { encoding: 'utf8' }).trim();
    const publicKey = execSync(`echo "${privateKey}" | wg pubkey`, { encoding: 'utf8' }).trim();
    return { privateKey, publicKey };
  } catch (error) {
    logger.error('Failed to generate WireGuard keys:', error);
    throw new Error('Key generation failed');
  }
}

function getNextAvailableIP() {
  // Simple IP allocation: start from 10.8.0.10 and increment
  // In production, this should check existing clients
  const baseIP = '10.8.0.';
  const startNum = 10;
  // For now, just use timestamp-based allocation to avoid conflicts
  const clientNum = startNum + (Date.now() % 240); // Max 250 clients
  return baseIP + clientNum;
}

async function loadClients() {
  try {
    const data = await fs.readFile(CONFIG.CLIENT_DATA_PATH, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    // File doesn't exist, return empty array
    return [];
  }
}

async function saveClients(clients) {
  await fs.writeFile(CONFIG.CLIENT_DATA_PATH, JSON.stringify(clients, null, 2));
}

async function getServerPublicKey() {
  try {
    return await fs.readFile(CONFIG.SERVER_PUBLIC_KEY_PATH, 'utf8').then(key => key.trim());
  } catch (error) {
    // Try to extract from server config
    try {
      const config = await fs.readFile(CONFIG.SERVER_CONFIG_PATH, 'utf8');
      const match = config.match(/# Server Public Key: (.+)/);
      if (match) return match[1];
      throw new Error('Server public key not found');
    } catch (configError) {
      logger.error('Failed to read server public key:', error);
      throw new Error('Server configuration error');
    }
  }
}

function generateClientConfig(clientData, serverPublicKey) {
  return `[Interface]
PrivateKey = ${clientData.privateKey}
Address = ${clientData.ipAddress}/32
DNS = ${CONFIG.DNS_SERVERS}

[Peer]
PublicKey = ${serverPublicKey}
Endpoint = ${CONFIG.WIREGUARD_SERVER_IP}:${CONFIG.WIREGUARD_PORT}
AllowedIPs = 192.168.0.0/24, ${CONFIG.VPN_NETWORK}
PersistentKeepalive = 25

# CrookedKeys Generated Config
# Client: ${clientData.name}
# Generated: ${new Date().toISOString()}
# Access: Frigate cameras and Home Assistant
`;
}

// API Routes

// Health check
app.get('/api/crooked-keys/health', (req, res) => {
  logger.info(`Health check from ${req.ip}`);
  res.json({
    status: 'healthy',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    service: 'crooked-keys'
  });
});

// Get VPN configuration (main endpoint for family)
app.post('/api/crooked-keys/get-vpn', keyExchangeLimiter, async (req, res) => {
  try {
    const { name, device } = req.body;
    
    if (!name || !device) {
      return res.status(400).json({ 
        error: 'Name and device type are required',
        example: { name: 'Aunt Sally', device: 'iPhone' }
      });
    }

    logger.info(`VPN config request from ${req.ip} for ${name} (${device})`);

    // Generate client keys
    const keys = generateWireGuardKeys();
    const ipAddress = getNextAvailableIP();
    
    // Create client data
    const clientData = {
      id: crypto.randomUUID(),
      name: name.trim(),
      device: device.trim(),
      publicKey: keys.publicKey,
      privateKey: keys.privateKey,
      ipAddress,
      createdAt: new Date().toISOString(),
      clientIP: req.ip,
      status: 'active'
    };

    // Save client data
    const clients = await loadClients();
    clients.push(clientData);
    await saveClients(clients);

    // Get server public key
    const serverPublicKey = await getServerPublicKey();
    
    // Generate config
    const configText = generateClientConfig(clientData, serverPublicKey);
    
    // Generate QR code
    const qrCodeDataURL = await QRCode.toDataURL(configText);

    logger.info(`Generated VPN config for ${name} (${device}) - IP: ${ipAddress}`);

    res.json({
      success: true,
      client: {
        name: clientData.name,
        device: clientData.device,
        ipAddress: clientData.ipAddress,
        id: clientData.id
      },
      config: configText,
      qrCode: qrCodeDataURL,
      instructions: {
        step1: 'Install WireGuard app on your device',
        step2: 'Either scan the QR code or import the config file',
        step3: 'Connect to access Frigate cameras and Home Assistant',
        downloadUrl: `/api/crooked-keys/download-config/${clientData.id}`
      }
    });

  } catch (error) {
    logger.error('VPN config generation failed:', error);
    res.status(500).json({ 
      error: 'Failed to generate VPN configuration',
      message: 'Please try again or contact support'
    });
  }
});

// Download config file
app.get('/api/crooked-keys/download-config/:clientId', async (req, res) => {
  try {
    const { clientId } = req.params;
    const clients = await loadClients();
    const client = clients.find(c => c.id === clientId);

    if (!client) {
      return res.status(404).json({ error: 'Config not found' });
    }

    const serverPublicKey = await getServerPublicKey();
    const configText = generateClientConfig(client, serverPublicKey);

    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('Content-Disposition', `attachment; filename="${client.name}_${client.device}.conf"`);
    res.send(configText);

    logger.info(`Config downloaded for ${client.name} (${client.device})`);

  } catch (error) {
    logger.error('Config download failed:', error);
    res.status(500).json({ error: 'Download failed' });
  }
});

// List active clients (admin endpoint)
app.get('/api/crooked-keys/clients', async (req, res) => {
  try {
    // This should be protected in production
    const clients = await loadClients();
    const sanitizedClients = clients.map(({ privateKey, ...client }) => client);
    
    res.json({
      clients: sanitizedClients,
      count: clients.length
    });
  } catch (error) {
    logger.error('Failed to list clients:', error);
    res.status(500).json({ error: 'Failed to retrieve clients' });
  }
});

// Revoke client access
app.delete('/api/crooked-keys/clients/:clientId', async (req, res) => {
  try {
    const { clientId } = req.params;
    const clients = await loadClients();
    const clientIndex = clients.findIndex(c => c.id === clientId);

    if (clientIndex === -1) {
      return res.status(404).json({ error: 'Client not found' });
    }

    const client = clients[clientIndex];
    client.status = 'revoked';
    client.revokedAt = new Date().toISOString();
    
    await saveClients(clients);
    
    logger.info(`Revoked access for ${client.name} (${client.device})`);
    
    res.json({ 
      success: true, 
      message: `Access revoked for ${client.name}`,
      client: { name: client.name, device: client.device }
    });

  } catch (error) {
    logger.error('Failed to revoke client:', error);
    res.status(500).json({ error: 'Failed to revoke access' });
  }
});

// Simple onboarding page
app.get('/api/crooked-keys/', (req, res) => {
  const html = `
<!DOCTYPE html>
<html>
<head>
    <title>CrookedServices VPN Access</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
        .form-group { margin: 15px 0; }
        input { padding: 10px; width: 100%; box-sizing: border-box; }
        button { background: #007cba; color: white; padding: 12px 24px; border: none; cursor: pointer; }
        button:hover { background: #005a87; }
        .result { margin-top: 20px; padding: 20px; background: #f0f8ff; border: 1px solid #ccc; }
        .qr-code { text-align: center; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>🔐 CrookedServices VPN Access</h1>
    <p>Get secure access to family cameras and home automation.</p>
    
    <form id="vpnForm">
        <div class="form-group">
            <label>Your Name:</label>
            <input type="text" id="name" placeholder="e.g., Aunt Sally" required>
        </div>
        <div class="form-group">
            <label>Device Type:</label>
            <input type="text" id="device" placeholder="e.g., iPhone, Android, Laptop" required>
        </div>
        <button type="submit">Get VPN Access</button>
    </form>
    
    <div id="result"></div>
    
    <script>
        document.getElementById('vpnForm').onsubmit = async function(e) {
            e.preventDefault();
            
            const name = document.getElementById('name').value;
            const device = document.getElementById('device').value;
            
            try {
                const response = await fetch('/api/crooked-keys/get-vpn', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ name, device })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    document.getElementById('result').innerHTML = \`
                        <h3>✅ VPN Configuration Ready!</h3>
                        <div class="qr-code">
                            <img src="\${data.qrCode}" alt="QR Code" style="max-width: 300px;">
                            <p>Scan with WireGuard app</p>
                        </div>
                        <p><strong>Your VPN IP:</strong> \${data.client.ipAddress}</p>
                        <p><a href="\${data.instructions.downloadUrl}" download>📁 Download Config File</a></p>
                        <h4>Setup Instructions:</h4>
                        <ol>
                            <li>\${data.instructions.step1}</li>
                            <li>\${data.instructions.step2}</li>
                            <li>\${data.instructions.step3}</li>
                        </ol>
                    \`;
                } else {
                    throw new Error(data.error || 'Unknown error');
                }
            } catch (error) {
                document.getElementById('result').innerHTML = \`
                    <h3>❌ Error</h3>
                    <p>\${error.message}</p>
                \`;
            }
        };
    </script>
</body>
</html>
  `;
  res.send(html);
});

// Error handling
app.use((error, req, res, next) => {
  logger.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  logger.info(`CrookedKeys service running on port ${PORT}`);
  console.log(`🔐 CrookedKeys Service Started`);
  console.log(`📡 Health: http://localhost:${PORT}/api/crooked-keys/health`);
  console.log(`🌐 Onboarding: http://localhost:${PORT}/api/crooked-keys/`);
});

module.exports = app;