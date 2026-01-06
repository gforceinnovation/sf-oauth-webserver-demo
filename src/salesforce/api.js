const axios = require('axios');

/**
 * Salesforce API Helper Functions
 */

/**
 * Get current user information from Salesforce
 */
async function getUserInfo(accessToken, instanceUrl) {
  try {
    const response = await axios.get(
      `${instanceUrl}/services/oauth2/userinfo`,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      }
    );
    console.log('✅ User info retrieved:', response.data.name);
    return response.data;
  } catch (error) {
    console.error('❌ Error fetching user info:', error.response?.data || error.message);
    throw new Error('Failed to fetch user info');
  }
}

/**
 * Create a Lead in Salesforce
 */
async function createLead(accessToken, instanceUrl, leadData) {
  const { firstName, lastName, company, email, phone } = leadData;

  // Validate required fields
  if (!lastName || !company) {
    throw new Error('Last Name and Company are required');
  }

  console.log('📝 Creating lead:', { firstName, lastName, company });

  try {
    const sfLeadData = {
      FirstName: firstName,
      LastName: lastName,
      Company: company,
      Email: email,
      Phone: phone,
      LeadSource: 'Web'
    };

    const response = await axios.post(
      `${instanceUrl}/services/data/v59.0/sobjects/Lead`,
      sfLeadData,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );

    console.log('✅ Lead created successfully! ID:', response.data.id);
    return {
      success: true,
      id: response.data.id,
      message: 'Lead created successfully'
    };
  } catch (error) {
    console.error('❌ Error creating lead:', error.response?.data || error.message);
    throw new Error('Failed to create lead: ' + (error.response?.data?.message || error.message));
  }
}

module.exports = {
  getUserInfo,
  createLead
};
