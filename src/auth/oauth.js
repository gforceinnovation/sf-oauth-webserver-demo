const crypto = require('crypto');
const axios = require('axios');

/**
 * OAuth Configuration and Helper Functions
 */

// PKCE Helper Functions
function generateCodeVerifier() {
  return crypto.randomBytes(32).toString('base64url');
}

function generateCodeChallenge(verifier) {
  return crypto.createHash('sha256').update(verifier).digest('base64url');
}

function generateState() {
  return crypto.randomBytes(16).toString('base64url');
}

/**
 * Initiate OAuth flow with PKCE
 * Generates code challenge and redirects to Salesforce login
 */
function initiateOAuthFlow(req, res, config) {
  console.log('🔐 Starting OAuth flow...');
  
  if (!config.clientId || !config.callbackUrl) {
    return res.status(500).send('Missing Salesforce configuration. Please check your .env file.');
  }
  
  // Generate PKCE values
  const codeVerifier = generateCodeVerifier();
  const codeChallenge = generateCodeChallenge(codeVerifier);
  const state = generateState();
  
  // Store code verifier in session for later use in token exchange
  req.session.codeVerifier = codeVerifier;
  req.session.oauthState = state;
  
  console.log('🔑 PKCE code challenge generated');
  
  const scope = config.scopes || 'openid profile email refresh_token api';

  // Build authorization URL with PKCE
  const authUrl = `${config.loginUrl}/services/oauth2/authorize?` +
    `response_type=code&` +
    `client_id=${encodeURIComponent(config.clientId)}&` +
    `redirect_uri=${encodeURIComponent(config.callbackUrl)}&` +
    `scope=${encodeURIComponent(scope)}&` +
    `state=${encodeURIComponent(state)}&` +
    `code_challenge=${codeChallenge}&` +
    `code_challenge_method=S256`;
  
  console.log('➡️  Redirecting to Salesforce...');
  res.redirect(authUrl);
}

/**
 * Handle OAuth callback from Salesforce
 * Exchanges authorization code for access token
 */
async function handleOAuthCallback(req, res, config) {
  const { code, error, error_description, state } = req.query;
  
  // Check for errors from Salesforce
  if (error) {
    console.error('❌ OAuth error from Salesforce:', error, error_description);
    return res.status(400).send(`Authorization failed: ${error_description || error}`);
  }
  
  if (!code) {
    console.error('❌ No authorization code received');
    return res.status(400).send('Authorization code not found');
  }
  
  // Get the code verifier from session (stored during initiation)
  const codeVerifier = req.session.codeVerifier;
  if (!codeVerifier) {
    console.error('❌ Code verifier not found in session');
    return res.status(400).send('Session expired. Please try again.');
  }

  const expectedState = req.session.oauthState;
  if (!expectedState || state !== expectedState) {
    console.error('❌ Invalid OAuth state');
    return res.status(400).send('Invalid OAuth state. Please try again.');
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
          code_verifier: codeVerifier  // PKCE code verifier
        },
        timeout: 10000
      }
    );

    const { access_token, instance_url } = tokenResponse.data;

    // Store token in session
    req.session.accessToken = access_token;
    req.session.instanceUrl = instance_url;
    
    // Clear the code verifier from session (no longer needed)
    delete req.session.codeVerifier;
    delete req.session.oauthState;

    console.log('✅ OAuth successful! Access token obtained');
    res.redirect('/app');
  } catch (error) {
    console.error('❌ Token exchange error:', error.response?.data || error.message);
    res.status(500).send(`Authentication failed: ${error.response?.data?.error_description || error.message}`);
  }
}

/**
 * Middleware to protect routes that require authentication
 */
function requireAuth(req, res, next) {
  if (!req.session.accessToken) {
    console.log('⛔ No access token, redirecting to login');
    return res.redirect('/');
  }
  next();
}

/**
 * Logout handler - destroys session
 */
function logout(req, res) {
  console.log('👋 Logging out...');
  req.session.destroy((err) => {
    if (err) {
      console.error('Error destroying session:', err);
    }
    res.json({ success: true });
  });
}

module.exports = {
  initiateOAuthFlow,
  handleOAuthCallback,
  requireAuth,
  logout
};
