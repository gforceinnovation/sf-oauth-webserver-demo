const express = require('express');
const session = require('express-session');
const axios = require('axios');
const path = require('path');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Simple configuration from .env file
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

// Simple session - just to pass token from OAuth callback to the app
app.use(session({
  secret: process.env.SESSION_SECRET || 'simple-demo-secret',
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 3600000 } // 1 hour
}));

// Serve static files
app.use(express.static('public'))
// Helper functions for PKCE
function generateCodeVerifier() {
  return crypto.randomBytes(32).toString('base64url');
}

function generateCodeChallenge(verifier) {
  return crypto.createHash('sha256').update(verifier).digest('base64url');
}
// Routes

// Home - always show login page (no session persistence)
app.get('/', (req, res) => {
  console.log('🏠 Home route');
  res.sendFile(path.join(__dirname, '../public/login.html'));
});

// Initiate OAuth flow
app.get('/auth/salesforce', (req, res) => {
  console.log('🔐 Starting OAuth flow...');
  
  if (!config.clientId || !config.callbackUrl) {
    return res.status(500).send('Missing Salesforce configuration. Please check your .env file.');
  }
  
  // Generate PKCE values
  const codeVerifier = generateCodeVerifier();
  const codeChallenge = generateCodeChallenge(codeVerifier);
  
  // Store code verifier in session for later use
  req.session.codeVerifier = codeVerifier;
  
  console.log('🔑 PKCE code challenge generated');
  
  const authUrl = `${config.loginUrl}/services/oauth2/authorize?` +
    `response_type=code&` +
    `client_id=${encodeURIComponent(config.clientId)}&` +
    `redirect_uri=${encodeURIComponent(config.callbackUrl)}&` +
    `code_challenge=${codeChallenge}&` +
    `code_challenge_method=S256`;
  
  console.log('➡️  Redirecting to Salesforce...');
  res.redirect(authUrl);
});

// OAuth callback
app.get('/oauth/callback', async (req, res) => {
  const { code, error, error_description } = req.query;
  
  if (error) {
    console.error('❌ OAuth error from Salesforce:', error, error_description);
    return res.status(400).send(`Authorization failed: ${error_description || error}`);
  }
  
  if (!code) {
    console.error('❌ No authorization code received');
    return res.status(400).send('Authorization code not found');
  }
  
  // Get the code verifier from session
  const codeVerifier = req.session.codeVerifier;
  if (!codeVerifier) {
    console.error('❌ Code verifier not found in session');
    return res.status(400).send('Session expired. Please try again.');
  }

  console.log('🔄 Exchanging authorization code for access token...');

  try {
    // Exchange authorization code for access token with PKCE
    const tokenResponse = await axios.post(
      `${config.loginUrl}/services/oauth2/token`,
      null,
      {
        params: {
          grant_type: 'authorization_code',
          code: code,
          client_id: config.clientId,
          client_secret: config.clientSecret,
          redirect_uri: config.callbackUrl,
          code_verifier: codeVerifier  // Add PKCE code verifier
        }
      }
    );

    const { access_token, instance_url } = tokenResponse.data;

    // Store token in session temporarily
    req.session.accessToken = access_token;
    req.session.instanceUrl = instance_url;
    
    // Clear the code verifier from session (no longer needed)
    delete req.session.codeVerifier;

    console.log('✅ OAuth successful! Redirecting to app...');
    res.redirect('/app');
  } catch (error) {
    console.error('❌ OAuth error:', error.response?.data || error.message);
    res.status(500).send(`Authentication failed: ${error.response?.data?.error_description || error.message}`);
  }
});

// App page - show lead form (after successful login)
app.get('/app', (req, res) => {
  if (!req.session.accessToken) {
    console.log('⛔ No access token, redirecting to login');
    return res.redirect('/');
  }
  console.log('📄 Serving app page');
  res.sendFile(path.join(__dirname, '../public/app.html'));
});

// Get current user info
app.get('/api/user', async (req, res) => {
  if (!req.session.accessToken) {
    return res.status(401).json({ error: 'Not authenticated' });
  }

  try {
    const response = await axios.get(
      `${req.session.instanceUrl}/services/oauth2/userinfo`,
      {
        headers: {
          'Authorization': `Bearer ${req.session.accessToken}`
        }
      }
    );
    console.log('✅ User info retrieved:', response.data.name);
    res.json(response.data);
  } catch (error) {
    console.error('❌ Error fetching user info:', error.response?.data || error.message);
    res.status(500).json({ error: 'Failed to fetch user info' });
  }
});

// Create Lead in Salesforce
app.post('/api/lead', async (req, res) => {
  if (!req.session.accessToken) {
    return res.status(401).json({ error: 'Not authenticated' });
  }

  const { firstName, lastName, company, email, phone } = req.body;

  if (!lastName || !company) {
    return res.status(400).json({ error: 'Last Name and Company are required' });
  }

  console.log('📝 Creating lead:', { firstName, lastName, company });

  try {
    const leadData = {
      FirstName: firstName,
      LastName: lastName,
      Company: company,
      Email: email,
      Phone: phone,
      LeadSource: 'Web'
    };

    const response = await axios.post(
      `${req.session.instanceUrl}/services/data/v59.0/sobjects/Lead`,
      leadData,
      {
        headers: {
          'Authorization': `Bearer ${req.session.accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );

    console.log('✅ Lead created successfully! ID:', response.data.id);
    res.json({ 
      success: true, 
      id: response.data.id,
      message: 'Lead created successfully'
    });
  } catch (error) {
    console.error('❌ Error creating lead:', error.response?.data || error.message);
    res.status(500).json({ 
      error: 'Failed to create lead',
      details: error.response?.data
    });
  }
});

// Logout - clear session and redirect to home
app.post('/api/logout', (req, res) => {
  console.log('👋 Logging out...');
  req.session.destroy((err) => {
    if (err) {
      console.error('Error destroying session:', err);
    }
    res.json({ success: true });
  });
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
