const express = require('express');
const session = require('express-session');
const path = require('path');
require('dotenv').config();

// Import modules
const oauth = require('./auth/oauth');
const salesforce = require('./salesforce/api');

const app = express();
const PORT = process.env.PORT || 3000;

// Salesforce configuration from .env file
const config = {
  clientId: process.env.SF_CLIENT_ID,
  clientSecret: process.env.SF_CLIENT_SECRET,
  callbackUrl: process.env.SF_CALLBACK_URL,
  loginUrl: process.env.SF_LOGIN_URL || 'https://login.salesforce.com'
};

console.log('🔧 Configuration loaded from .env');
console.log('   Client ID:', config.clientId ? '✓ Set' : '✗ Missing');
console.log('   Client Secret:', config.clientSecret ? '✓ Set' : '✗ Missing');
console.log('   Callback URL:', config.callbackUrl || '✗ Missing');

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Session configuration
app.use(session({
  secret: process.env.SESSION_SECRET || 'simple-demo-secret',
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 3600000 } // 1 hour
}));

// Serve static files
app.use(express.static('public'));

// ==================== Routes ====================

// Home - always show login page
app.get('/', (req, res) => {
  console.log('🏠 Home route');
  res.sendFile(path.join(__dirname, '../public/login.html'));
});

// Initiate OAuth flow
app.get('/auth/salesforce', (req, res) => {
  oauth.initiateOAuthFlow(req, res, config);
});

// OAuth callback
app.get('/oauth/callback', async (req, res) => {
  await oauth.handleOAuthCallback(req, res, config);
});

// App page - show lead form (requires authentication)
app.get('/app', oauth.requireAuth, (req, res) => {
  console.log('📄 Serving app page');
  res.sendFile(path.join(__dirname, '../public/app.html'));
});

// ==================== API Routes ====================

// Get current user info
app.get('/api/user', async (req, res) => {
  if (!req.session.accessToken) {
    return res.status(401).json({ error: 'Not authenticated' });
  }

  try {
    const userInfo = await salesforce.getUserInfo(
      req.session.accessToken,
      req.session.instanceUrl
    );
    res.json(userInfo);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create Lead in Salesforce
app.post('/api/lead', async (req, res) => {
  if (!req.session.accessToken) {
    return res.status(401).json({ error: 'Not authenticated' });
  }

  try {
    const result = await salesforce.createLead(
      req.session.accessToken,
      req.session.instanceUrl,
      req.body
    );
    res.json(result);
  } catch (error) {
    res.status(500).json({ 
      error: 'Failed to create lead',
      details: error.message
    });
  }
});

// Logout
app.post('/api/logout', (req, res) => {
  oauth.logout(req, res);
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Start server
app.listen(PORT, () => {
  console.log('🚀 Server running on port', PORT);
  console.log('🌐 Open http://localhost:' + PORT);
  console.log('');
});
