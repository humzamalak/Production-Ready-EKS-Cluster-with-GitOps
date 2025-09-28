const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: process.env.APP_VERSION || '1.0.0'
  });
});

// Readiness probe endpoint
app.get('/ready', (req, res) => {
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// Main route
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>K8s Web App</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                margin: 0;
                padding: 0;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            .container {
                background: white;
                border-radius: 20px;
                padding: 3rem;
                box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                text-align: center;
                max-width: 600px;
                margin: 2rem;
            }
            h1 {
                color: #333;
                margin-bottom: 1rem;
                font-size: 2.5rem;
            }
            .status {
                background: #f8f9fa;
                border-radius: 10px;
                padding: 1.5rem;
                margin: 2rem 0;
                border-left: 4px solid #28a745;
            }
            .info {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 1rem;
                margin: 2rem 0;
            }
            .info-item {
                background: #e9ecef;
                padding: 1rem;
                border-radius: 8px;
            }
            .info-label {
                font-weight: bold;
                color: #495057;
                margin-bottom: 0.5rem;
            }
            .info-value {
                color: #6c757d;
                font-family: monospace;
            }
            .footer {
                margin-top: 2rem;
                color: #6c757d;
                font-size: 0.9rem;
            }
            .k8s-logo {
                font-size: 3rem;
                margin-bottom: 1rem;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="k8s-logo">☸️</div>
            <h1>Welcome to K8s Web App</h1>
            <div class="status">
                <strong>✅ Application is running successfully!</strong>
            </div>
            
            <div class="info">
                <div class="info-item">
                    <div class="info-label">Environment</div>
                    <div class="info-value">${process.env.NODE_ENV || 'development'}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Version</div>
                    <div class="info-value">${process.env.APP_VERSION || '1.0.0'}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Port</div>
                    <div class="info-value">${PORT}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Uptime</div>
                    <div class="info-value">${Math.floor(process.uptime())}s</div>
                </div>
            </div>
            
            <div class="footer">
                <p>Deployed on Kubernetes with ArgoCD GitOps</p>
                <p>Built with Node.js and Express</p>
            </div>
        </div>
    </body>
    </html>
  `);
});

// API routes
app.get('/api/info', (req, res) => {
  res.json({
    message: 'Welcome to K8s Web App API',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
    pod: {
      name: process.env.HOSTNAME || 'unknown',
      namespace: process.env.NAMESPACE || 'default'
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: 'Something went wrong!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Start server
app.listen(PORT, HOST, () => {
  console.log(`🚀 Server running on http://${HOST}:${PORT}`);
  console.log(`📊 Health check available at http://${HOST}:${PORT}/health`);
  console.log(`🔍 Readiness probe at http://${HOST}:${PORT}/ready`);
});

module.exports = app;
