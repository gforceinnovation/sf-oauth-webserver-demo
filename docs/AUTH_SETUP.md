# Salesforce OAuth Setup Guide

This guide explains how to set up OAuth 2.0 authentication with Salesforce for your web application using the Web Server Flow with PKCE (Proof Key for Code Exchange).

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Step 1: Create a Salesforce Connected App](#step-1-create-a-salesforce-connected-app)
- [Step 2: Configure Your Application](#step-2-configure-your-application)
- [Step 3: Test the OAuth Flow](#step-3-test-the-oauth-flow)
- [How It Works](#how-it-works)
- [Security Features](#security-features)
- [Troubleshooting](#troubleshooting)

---

## Overview

This application implements the **OAuth 2.0 Web Server Flow** with **PKCE** to securely authenticate users with Salesforce. This allows your app to:

- Authenticate users via Salesforce login
- Access Salesforce data on behalf of the user
- Create and manage Salesforce records (e.g., Leads)

### Why PKCE?

PKCE (Proof Key for Code Exchange) adds an extra layer of security to prevent authorization code interception attacks. Salesforce now requires PKCE for all OAuth flows.

---

## Prerequisites

Before you begin, ensure you have:

- ✅ A Salesforce account (Developer Edition or higher)
- ✅ Administrator access to your Salesforce org
- ✅ Node.js 18+ installed
- ✅ This application code

---

## Step 1: Create a Salesforce Connected App

A Connected App in Salesforce allows external applications to integrate with Salesforce using OAuth.

### 1.1 Navigate to App Manager

1. Log in to your Salesforce org
2. Click the **gear icon** (⚙️) in the top right
3. Select **Setup**
4. In the Quick Find box, search for **App Manager**
5. Click **App Manager**

### 1.2 Create New Connected App

1. Click **New Connected App** (top right)
2. Fill in the basic information:

   **Connected App Name:** `SF OAuth Demo`  
   **API Name:** `sf_oauth_demo` (auto-filled)  
   **Contact Email:** `your-email@example.com`

### 1.3 Enable OAuth Settings

1. Check ✅ **Enable OAuth Settings**

2. **Callback URL:**
   - For local development: `http://localhost:3000/oauth/callback`
   - For production: `https://yourdomain.com/oauth/callback`
   - You can add multiple callback URLs (one per line)

3. **Selected OAuth Scopes:** Add these scopes by selecting them and clicking the **Add** arrow:
   - **Full access (full)**
   - **Perform requests at any time (refresh_token, offline_access)**
   - **Access and manage your data (api)**

4. **Require Secret for Web Server Flow:**
   - Keep this checked ✅ (recommended for security)

5. **Require Secret for Refresh Token Flow:**
   - Keep this checked ✅

6. **Enable PKCE Extension for Supported Authorization Flows:**
   - Check ✅ **Require Proof Key for Code Exchange (PKCE) Extension for Supported Authorization Flows**

### 1.4 Save and Wait

1. Click **Save**
2. Click **Continue** on the warning screen
3. ⏱️ **Wait 2-10 minutes** for the changes to propagate

### 1.5 Get Your Credentials

1. After saving, you'll see your Connected App details
2. Click **Manage Consumer Details** button
3. You may be prompted to verify your identity (enter verification code sent to email)
4. Copy these values:
   - **Consumer Key** (Client ID)
   - **Consumer Secret** (Client Secret)

---

## Step 2: Configure Your Application

### 2.1 Create `.env` File

In your project root, create a `.env` file (if it doesn't exist):

```bash
cp .env.example .env
```

### 2.2 Add Your Salesforce Credentials

Edit the `.env` file and add your Salesforce credentials:

```env
# Salesforce OAuth Configuration
SF_CLIENT_ID=<paste your Consumer Key here>
SF_CLIENT_SECRET=<paste your Consumer Secret here>
SF_CALLBACK_URL=http://localhost:3000/oauth/callback
SF_LOGIN_URL=https://login.salesforce.com

# Application Configuration
PORT=3000
SESSION_SECRET=<generate a random string - see below>
```

### 2.3 Generate Session Secret

Run this command to generate a secure random session secret:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Copy the output and paste it as your `SESSION_SECRET` value.

### 2.4 Install Dependencies

```bash
npm install
```

---

## Step 3: Test the OAuth Flow

### 3.1 Start the Server

```bash
npm start
```

You should see:
```
🔧 Configuration loaded from .env
   Client ID: ✓ Set
   Client Secret: ✓ Set
   Callback URL: http://localhost:3000/oauth/callback
🚀 Server running on port 3000
🌐 Open http://localhost:3000
```

### 3.2 Test the Login Flow

1. Open your browser to **http://localhost:3000**
2. Click **Login with Salesforce** button
3. You'll be redirected to Salesforce login page
4. Enter your Salesforce credentials
5. **First time only:** You'll see an approval screen - click **Allow**
6. You'll be redirected back to your app
7. You should now see the Lead creation form

### 3.3 Test Creating a Lead

1. Fill in the lead form:
   - First Name: `John`
   - Last Name: `Doe` (required)
   - Company: `Test Company` (required)
   - Email: `john.doe@example.com`
   - Phone: `555-1234`

2. Click **Create Lead**

3. You should see a success message with the Lead ID

4. Verify in Salesforce:
   - Go to Salesforce
   - Navigate to **Leads** tab
   - You should see your newly created lead

---

## How It Works

### OAuth 2.0 Web Server Flow with PKCE

The OAuth 2.0 Web Server Flow is the most secure method for server-side applications to authenticate with Salesforce. When combined with PKCE (Proof Key for Code Exchange), it provides protection against authorization code interception attacks.

#### High-Level Flow Diagram

```
┌──────────┐                                           ┌─────────────┐
│          │                                           │             │
│   User   │                                           │ Salesforce  │
│  Browser │                                           │   Server    │
│          │                                           │             │
└────┬─────┘                                           └──────┬──────┘
     │                                                        │
     │  1. Click "Login with Salesforce"                     │
     │     GET /auth/salesforce                              │
     ├──────────────────────────────────────────────────────►│
     │                                                        │
     │  2. Redirect to Salesforce Authorization              │
     │     + client_id                                        │
     │     + redirect_uri                                     │
     │     + code_challenge (PKCE)                            │
     │     + code_challenge_method=S256                       │
     │◄───────────────────────────────────────────────────────┤
     │                                                        │
     │  3. User Logs In & Approves                           │
     ├──────────────────────────────────────────────────────►│
     │                                                        │
     │  4. Redirect to Callback with Authorization Code      │
     │     GET /oauth/callback?code=ABC123...                │
     │◄───────────────────────────────────────────────────────┤
     │                                                        │
┌────▼─────┐                                           ┌──────▼──────┐
│          │                                           │             │
│   App    │  5. Exchange Code for Access Token       │ Salesforce  │
│  Server  │     POST /services/oauth2/token          │   OAuth     │
│          │     + code                                │   Server    │
│          │     + client_id                           │             │
│          │     + client_secret                       │             │
│          │     + code_verifier (PKCE)                │             │
│          ├──────────────────────────────────────────►│             │
│          │                                           │             │
│          │  6. Return Access Token                   │             │
│          │     {                                     │             │
│          │       "access_token": "00D...",           │             │
│          │       "instance_url": "https://...",      │             │
│          │       "id": "...",                         │             │
│          │       "token_type": "Bearer"              │             │
│          │     }                                     │             │
│          │◄──────────────────────────────────────────┤             │
└──────────┘                                           └─────────────┘
     │
     │  7. Store Access Token in Session
     │  8. Make API Calls with Access Token
     ▼
```

---

### Detailed Step-by-Step Process

#### Step 1: User Initiates Login (`GET /auth/salesforce`)

**What Happens:**
- User clicks "Login with Salesforce" button
- Your app's server receives the request

**App Server Actions:**
```javascript
// 1. Generate PKCE code_verifier (random 32-byte string)
const codeVerifier = crypto.randomBytes(32).toString('base64url');
// Example: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

// 2. Create code_challenge (SHA256 hash of verifier)
const codeChallenge = crypto
  .createHash('sha256')
  .update(codeVerifier)
  .digest('base64url');
// Example: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

// 3. Store code_verifier in session (for later verification)
req.session.codeVerifier = codeVerifier;

// 4. Build authorization URL
const authUrl = `${SF_LOGIN_URL}/services/oauth2/authorize?` +
  `response_type=code&` +
  `client_id=${CLIENT_ID}&` +
  `redirect_uri=${CALLBACK_URL}&` +
  `code_challenge=${codeChallenge}&` +
  `code_challenge_method=S256`;

// 5. Redirect user to Salesforce
res.redirect(authUrl);
```

**Why PKCE?**
- The `code_verifier` is kept secret on the server
- Only the `code_challenge` (hash) is sent to Salesforce
- This prevents attackers from intercepting and using the authorization code

---

#### Step 2: User Authenticates with Salesforce

**What Happens:**
- User is redirected to Salesforce login page
- User enters Salesforce username and password
- User is shown an authorization screen (first time only)
- User clicks "Allow" to grant access

**Salesforce Validates:**
- User credentials
- App's `client_id` is valid
- App's `redirect_uri` matches configuration
- PKCE `code_challenge` is received

---

#### Step 3: Salesforce Returns Authorization Code (`GET /oauth/callback`)

**What Happens:**
- After successful authentication, Salesforce redirects back to your app
- URL includes an authorization code

**Example Callback:**
```
http://localhost:3000/oauth/callback?code=aPrxsmIEeqM9PiQroGEWx1UiMQd95_5JUZ...
```

**Important Notes:**
- Authorization code is valid for **15 minutes only**
- Code can only be used **once**
- Code is tied to the specific `code_challenge` sent in Step 1

---

#### Step 4: Exchange Authorization Code for Access Token

**What Happens:**
- Your app's server receives the authorization code
- Server must exchange this code for an access token
- This exchange happens **server-to-server** (secure)

**App Server Actions:**
```javascript
// 1. Extract authorization code from callback
const authCode = req.query.code;

// 2. Retrieve code_verifier from session
const codeVerifier = req.session.codeVerifier;

// 3. Send token request to Salesforce
POST https://login.salesforce.com/services/oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
code=aPrxsmIEeqM9PiQroGEWx1UiMQd95_5JUZ...
client_id=3MVG9IHf89I1t8hrvsw...
client_secret=*******************
redirect_uri=http://localhost:3000/oauth/callback
code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

**Salesforce Validates:**
1. **Authorization code** is valid and not expired
2. **Client ID and secret** match registered app
3. **Redirect URI** matches the one used in Step 1
4. **PKCE verification:** Hashes the `code_verifier` and compares it to the original `code_challenge`
   ```
   SHA256(code_verifier) === code_challenge
   ```

If all validations pass, Salesforce returns an access token.

---

#### Step 5: Salesforce Returns Access Token

**Response from Salesforce:**
```json
{
  "access_token": "00DB0000000TfcR!AQQAQFhoK8vTMg_rKA.esrJ2bCs...",
  "instance_url": "https://mycompany.my.salesforce.com",
  "id": "https://login.salesforce.com/id/00DB0000000TfcRMAS/005B0000005Bk90IAC",
  "token_type": "Bearer",
  "issued_at": "1558553873237",
  "signature": "d/SxeYBxH0GSVko0HMgcUxuZy0PA2cDDz1u7g7JtDHw=",
  "scope": "api web openid"
}
```

**App Server Actions:**
```javascript
// 1. Store access token in session
req.session.accessToken = response.data.access_token;
req.session.instanceUrl = response.data.instance_url;

// 2. Clear code_verifier (no longer needed)
delete req.session.codeVerifier;

// 3. Redirect user to app page
res.redirect('/app');
```

---

#### Step 6: Access Protected Resources

**Making API Calls:**
Now that you have an access token, you can make authenticated API calls to Salesforce:

```javascript
// Example: Get user info
GET https://mycompany.my.salesforce.com/services/oauth2/userinfo
Authorization: Bearer 00DB0000000TfcR!AQQAQFhoK8vTMg_rKA.esrJ2bCs...

// Example: Create a Lead
POST https://mycompany.my.salesforce.com/services/data/v59.0/sobjects/Lead
Authorization: Bearer 00DB0000000TfcR!AQQAQFhoK8vTMg_rKA.esrJ2bCs...
Content-Type: application/json

{
  "FirstName": "John",
  "LastName": "Doe",
  "Company": "Test Company",
  "LeadSource": "Web"
}
```

---

### Why Web Server Flow with PKCE is Secure

#### Traditional Security Concerns

**Without PKCE:**
1. Attacker intercepts authorization code during redirect
2. Attacker exchanges code for access token using client_id and client_secret
3. Attacker gains unauthorized access

#### How PKCE Prevents This

**With PKCE:**
1. **Step 1:** App generates random `code_verifier` (kept secret on server)
2. **Step 1:** App creates `code_challenge = SHA256(code_verifier)`
3. **Step 1:** Only `code_challenge` is sent to Salesforce
4. **Step 3:** Attacker intercepts authorization code
5. **Step 4:** Attacker cannot exchange code without the original `code_verifier`
6. **Step 4:** Salesforce validates: `SHA256(code_verifier) === code_challenge`
7. **Result:** Attack fails because attacker doesn't know the `code_verifier`

#### Security Layers

1. **Client Secret:** Only your server knows this (never in browser)
2. **PKCE Code Verifier:** Randomly generated per request, stored in server session
3. **Authorization Code:** Short-lived (15 min), one-time use
4. **Access Token:** Stored in secure server session, not in browser
5. **HTTPS:** All communication encrypted in production

---

### Session Management

#### Token Lifecycle in This App

```
User Logs In
    ↓
Authorization Code Generated (15 min expiry)
    ↓
Access Token Obtained
    ↓
Stored in Server Session (1 hour expiry)
    ↓
Used for API Calls
    ↓
Session Expires or User Logs Out
    ↓
Token Destroyed
```

#### Session Storage
```javascript
req.session = {
  codeVerifier: "dBjftJeZ...",  // During OAuth flow only
  accessToken: "00DB0000...",   // After successful auth
  instanceUrl: "https://..."    // Salesforce instance
}
```

#### Token Expiration
- **Authorization Code:** 15 minutes
- **Access Token:** Depends on session (1 hour in this app)
- **Session:** 1 hour (configurable)

**For Production:**
- Implement refresh token flow for seamless re-authentication
- Use persistent session store (Redis, Database)
- Set appropriate token expiration policies

---

## Security Features

### 1. PKCE (Proof Key for Code Exchange)

- Prevents authorization code interception attacks
- Uses a cryptographically random `code_verifier`
- Creates a SHA256 hash as `code_challenge`
- Verifier is only known to the legitimate app

### 2. Session Security

- Session secret stored in environment variables
- Session expires after 1 hour
- Tokens never exposed in URLs
- HTTPS recommended for production

### 3. Client Secret Protection

- Client secret stored in `.env` file
- Never committed to version control
- Only used in server-side code
- AWS Secrets Manager for production (optional)

---

## Troubleshooting

### Error: "missing required code challenge"

**Solution:** Ensure your Connected App has PKCE enabled:
- In Salesforce, edit your Connected App
- Check ✅ "Require Proof Key for Code Exchange (PKCE) Extension"
- Save and wait 2-10 minutes

### Error: "redirect_uri_mismatch"

**Solution:** Callback URL must match exactly:
- Check your `.env` file: `SF_CALLBACK_URL`
- Check Connected App settings in Salesforce
- URLs must match including protocol (http/https)

### Error: "invalid_client_id"

**Solution:** 
- Verify your Consumer Key is correct in `.env`
- Wait 2-10 minutes after creating the Connected App
- Ensure no extra spaces or newlines in the `.env` file

### Error: "invalid_grant"

**Solution:**
- Authorization code expired (valid for 15 minutes)
- Try the login flow again
- Clear browser cookies and try again

### Session Expired

**Solution:**
- Sessions expire after 1 hour
- Click logout and login again
- For longer sessions, implement refresh token flow

---

## Production Deployment

When deploying to production:

1. **Use HTTPS:**
   - Update callback URL to `https://yourdomain.com/oauth/callback`
   - Update Connected App with production URL

2. **Environment Variables:**
   - Use environment variables (not `.env` file)
   - Consider AWS Secrets Manager or similar

3. **Session Store:**
   - Use Redis or database for session storage
   - Don't use in-memory sessions

4. **Security Headers:**
   - Add helmet.js for security headers
   - Enable CORS properly
   - Use secure cookies

---

## Additional Resources

- [Salesforce OAuth 2.0 Documentation](https://help.salesforce.com/s/articleView?id=sf.remoteaccess_oauth_web_server_flow.htm)
- [OAuth 2.0 Specification](https://oauth.net/2/)
- [PKCE Extension](https://oauth.net/2/pkce/)

---

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review Salesforce OAuth documentation
3. Check application logs in the terminal

---

**Last Updated:** January 6, 2026
