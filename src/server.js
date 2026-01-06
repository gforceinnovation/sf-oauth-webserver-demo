const express = require('express');
const session = require('express-session');
const axios = require('axios');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static('public'));

// Session configuration
app.use(session({
  secret: process.env.SESSION_SECRET || 'dev-secret-change-in-production',
  resave: false,
  saveUninitialized: false,
  cookie: { 
    secure: process.env.NODE_ENV === 'production',
    maxAge: 3600000 // 1 hour
  }
}));

// Configuration from environment or AWS Secrets Manager
let config = {
  clientId: process.env.SF_CLIENT_ID,
  clientSecret: process.env.SF_CLIENT_SECRET,
  callbackUrl: process.env.SF_CALLBACK_URL,
  loginUrl: process.env.SF_LOGIN_URL || 'https://login.salesforce.com'
};

// AWS Secrets Manager integration for production
async function loadConfigFromAWS() {
  if (process.env.AWS_SECRET_NAME) {
    try {
      const AWS = require('aws-sdk');
      const secretsManager = new AWS.SecretsManager({
        region: process.env.AWS_REGION || 'us-east-1'
      });
      
      const data = await secretsManager.getSecretValue({
        SecretId: process.env.AWS_SECRET_NAME
      }).promise();
      
      const secret = JSON.parse(data.SecretString);
      config = {
        clientId: secret.SF_CLIENT_ID,
        clientSecret: secret.SF_CLIENT_SECRET,
        callbackUrl: secret.SF_CALLBACK_URL,
        loginUrl: secret.SF_LOGIN_URL || 'https://login.salesforce.com'
      };
      console.log('Configuration loaded from AWS Secrets Manager');
    } catch (error) {
      console.error('Error loading from AWS Secrets Manager:', error);
      console.log('Falling back to environment variables');
    }
  }
}

// Routes

// Home page - serve the main HTML
app.get('/', (req, res) => {
  if (!req.session.accessToken) {
    res.sendFile(path.join(__dirname, '../public/login.html'));
  } else {
    res.sendFile(path.join(__dirname, '../public/index.html'));
  }
});

// Initiate OAuth flow
app.get('/auth/salesforce', (req, res) => {
  const authUrl = `${config.loginUrl}/services/oauth2/authorize?` +
    `response_type=code&` +
    `client_id=${encodeURIComponent(config.clientId)}&` +
    `redirect_uri=${encodeURIComponent(config.callbackUrl)}`;
  
  console.log('Redirecting to Salesforce OAuth...');
  res.redirect(authUrl);
});

// OAuth callback
app.get('/oauth/callback', async (req, res) => {
  const { code } = req.query;
  
  if (!code) {
    return res.status(400).send('Authorization code not found');
  }

  try {
    // Exchange authorization code for access token
    const tokenResponse = await axios.post(
      `${config.loginUrl}/services/oauth2/token`,
      null,
      {
        params: {
          grant_type: 'authorization_code',
          code: code,
          client_id: config.clientId,
          client_secret: config.clientSecret,
          redirect_uri: config.callbackUrl
        }
      }
    );

    const { access_token, instance_url, refresh_token } = tokenResponse.data;

    // Store in session
    req.session.accessToken = access_token;
    req.session.instanceUrl = instance_url;
    req.session.refreshToken = refresh_token;

    console.log('OAuth successful, access token obtained');
    res.redirect('/');
  } catch (error) {
    console.error('OAuth error:', error.response?.data || error.message);
    res.status(500).send(`Authentication failed: ${error.response?.data?.error_description || error.message}`);
  }
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
    res.json(response.data);
  } catch (error) {
    console.error('Error fetching user info:', error.response?.data || error.message);
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

    console.log('Lead created successfully:', response.data.id);
    res.json({ 
      success: true, 
      id: response.data.id,
      message: 'Lead created successfully'
    });
  } catch (error) {
    console.error('Error creating lead:', error.response?.data || error.message);
    res.status(500).json({ 
      error: 'Failed to create lead',
      details: error.response?.data
    });
  }
});

// Logout
app.post('/api/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      console.error('Error destroying session:', err);
    }
    res.json({ success: true });
  });
});

// Health check endpoint for AWS
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Start server
async function startServer() {
  await loadConfigFromAWS();
  
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  });
}

startServer();
