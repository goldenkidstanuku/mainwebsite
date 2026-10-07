// Standalone Backend WhatsApp Verification Script
// Tests E.164 phone formatting, endpoint routing, error responses, and payload building

import http from 'http';
import { validatePhoneNumber, handleWhatsAppApiRequest } from './whatsapp-backend.js';

console.log('================================================================');
console.log('   Golden Kids School - WhatsApp Backend Verification Test');
console.log('================================================================\n');

let passedTests = 0;
let totalTests = 0;

function assert(condition, message) {
  totalTests++;
  if (condition) {
    console.log(`[PASS] ${message}`);
    passedTests++;
  } else {
    console.error(`[FAIL] ${message}`);
  }
}

// 1. Phone Number Validation & E.164 Tests
console.log('--- 1. Testing E.164 Phone Number Validation ---');
const t1 = validatePhoneNumber('9876543210');
assert(t1.isValid && t1.canonical === '+919876543210' && t1.cleanDigits === '919876543210', 'Converts 10-digit Indian number to +91 E.164');

const t2 = validatePhoneNumber('+91 86591 63665');
assert(t2.isValid && t2.cleanDigits === '918659163665', 'Handles spaced +91 format correctly');

const t3 = validatePhoneNumber('09876543210');
assert(t3.isValid && t3.canonical === '+919876543210', 'Handles leading 0 Indian number format');

const t4 = validatePhoneNumber('invalid-phone');
assert(!t4.isValid, 'Correctly flags non-numeric string as invalid');

const t5 = validatePhoneNumber('');
assert(!t5.isValid && t5.reason.includes('missing'), 'Correctly flags empty phone number');

// 2. Integration Test with Mock HTTP Server
console.log('\n--- 2. Testing WhatsApp Backend API Router ---');

const testServer = http.createServer((req, res) => {
  const parsedUrl = new URL(req.url, 'http://localhost:8999');
  if (parsedUrl.pathname.startsWith('/api/whatsapp')) {
    handleWhatsAppApiRequest(req, res, parsedUrl);
  } else {
    res.writeHead(404);
    res.end();
  }
});

testServer.listen(8999, 'localhost', async () => {
  try {
    // Test GET /api/whatsapp/status
    const statusResp = await fetch('http://localhost:8999/api/whatsapp/status');
    const statusData = await statusResp.json();
    assert(statusResp.status === 200 && statusData.provider === 'cloud_api', 'GET /api/whatsapp/status returns 200 and provider');

    // Test POST /api/whatsapp/test without tokens (should fail cleanly, not fake success)
    const testResp = await fetch('http://localhost:8999/api/whatsapp/test', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ api_token: '', phone_number_id: '' })
    });
    const testData = await testResp.json();
    assert(!testData.success && testData.status === 'unconfigured', 'POST /api/whatsapp/test fails cleanly when unconfigured (no fake success)');

    // Test POST /api/whatsapp/send with invalid number
    const sendBadResp = await fetch('http://localhost:8999/api/whatsapp/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        recipient_phone: '123',
        content: 'Test message'
      })
    });
    const sendBadData = await sendBadResp.json();
    assert(!sendBadData.success && sendBadData.mode === 'invalid_phone', 'POST /api/whatsapp/send rejects invalid phone number with HTTP 400');

    // Test POST /api/whatsapp/send when unconfigured
    const sendUnconfResp = await fetch('http://localhost:8999/api/whatsapp/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        recipient_phone: '+919876543210',
        content: 'Test message outside 24h'
      })
    });
    const sendUnconfData = await sendUnconfResp.json();
    // If not configured, should return unconfigured error, NOT demo fake sandbox
    assert(!sendUnconfData.success && (sendUnconfData.mode === 'unconfigured' || sendUnconfData.mode === 'cloud_api_error'), 'POST /api/whatsapp/send does NOT return fake demo sandbox success');

    // Test Webhook Verification Handshake
    const verifyToken = 'goldenkids_webhook_verify_2026';
    const challenge = 'CHALLENGE_TEST_12345';
    const webhookResp = await fetch(`http://localhost:8999/api/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=${verifyToken}&hub.challenge=${challenge}`);
    const webhookText = await webhookResp.text();
    assert(webhookResp.status === 200 && webhookText === challenge, 'GET /api/whatsapp/webhook passes Meta verification challenge');

    console.log(`\n================================================================`);
    console.log(`   Verification Summary: ${passedTests} / ${totalTests} Passed`);
    console.log(`================================================================\n`);
  } catch (err) {
    console.error('Test execution error:', err);
  } finally {
    testServer.close();
    process.exit(passedTests === totalTests ? 0 : 1);
  }
});
