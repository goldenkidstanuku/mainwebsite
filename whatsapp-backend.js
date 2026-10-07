import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DATA_DIR = path.join(__dirname, 'data');
const CONFIG_FILE = path.join(DATA_DIR, 'whatsapp-config.json');
const MESSAGES_FILE = path.join(DATA_DIR, 'whatsapp-messages.json');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  try {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  } catch (e) {
    console.error('[WhatsApp Backend] Failed to create data dir:', e);
  }
}

// Native .env file loader for WhatsApp backend
function loadEnv() {
  const envPath = path.join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    try {
      const content = fs.readFileSync(envPath, 'utf8');
      content.split(/\r?\n/).forEach(line => {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) return;
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx > 0) {
          const key = trimmed.slice(0, eqIdx).trim();
          let val = trimmed.slice(eqIdx + 1).trim();
          if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
            val = val.slice(1, -1);
          }
          if (!process.env[key]) {
            process.env[key] = val;
          }
        }
      });
    } catch (e) {
      console.warn('[WhatsApp Backend] Could not load .env file:', e.message);
    }
  }
}
loadEnv();

// Default Configuration from Environment or Storage
const DEFAULT_CONFIG = {
  provider: 'cloud_api',
  business_phone: process.env.META_PHONE_NUMBER || '+91 86591 63665',
  business_account_id: process.env.META_WABA_ID || '',
  phone_number_id: process.env.META_PHONE_NUMBER_ID || '',
  api_token: process.env.META_WHATSAPP_TOKEN || '',
  environment: process.env.META_WHATSAPP_TOKEN ? 'production' : 'unconfigured',
  webhook_url: 'https://goldenkids.supabase.co/functions/v1/whatsapp-webhook',
  webhook_verify_token: process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || 'goldenkids_webhook_verify_2026',
  rate_limit_per_second: 20,
  daily_quota: 10000,
  is_connected: Boolean(process.env.META_WHATSAPP_TOKEN && process.env.META_PHONE_NUMBER_ID),
  last_tested_at: null
};

let currentConfig = { ...DEFAULT_CONFIG };
let messageStore = [];

function loadConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      const raw = fs.readFileSync(CONFIG_FILE, 'utf8');
      const saved = JSON.parse(raw);
      currentConfig = {
        ...DEFAULT_CONFIG,
        ...saved,
        // Allow environment variables to override empty config values
        api_token: saved.api_token || process.env.META_WHATSAPP_TOKEN || '',
        phone_number_id: saved.phone_number_id || process.env.META_PHONE_NUMBER_ID || '',
        business_account_id: saved.business_account_id || process.env.META_WABA_ID || ''
      };
      currentConfig.is_connected = Boolean(currentConfig.api_token && currentConfig.phone_number_id);
    }
  } catch (e) {
    console.error('[WhatsApp Backend] Error loading config:', e);
  }
}

function saveConfigToDisk() {
  try {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(currentConfig, null, 2), 'utf8');
  } catch (e) {
    console.error('[WhatsApp Backend] Error saving config:', e);
  }
}

function loadMessages() {
  try {
    if (fs.existsSync(MESSAGES_FILE)) {
      const raw = fs.readFileSync(MESSAGES_FILE, 'utf8');
      messageStore = JSON.parse(raw);
    }
  } catch (e) {
    console.error('[WhatsApp Backend] Error loading messages:', e);
  }
}

function saveMessagesToDisk() {
  try {
    const trimmed = messageStore.slice(0, 1000);
    fs.writeFileSync(MESSAGES_FILE, JSON.stringify(trimmed, null, 2), 'utf8');
  } catch (e) {
    console.error('[WhatsApp Backend] Error saving messages:', e);
  }
}

// Initialize storage
loadConfig();
loadMessages();

// Canonicalize and validate phone number to E.164 format
export function validatePhoneNumber(raw) {
  if (!raw || !String(raw).trim()) {
    return { isValid: false, formatted: '', canonical: '', cleanDigits: '', reason: 'WhatsApp recipient phone number is missing' };
  }
  const cleaned = String(raw).trim().replace(/[\s\-\(\)\.]/g, '');
  let canonical = cleaned;
  if (canonical.startsWith('0')) {
    canonical = '+91' + canonical.slice(1);
  } else if (canonical.startsWith('91') && canonical.length === 12) {
    canonical = '+' + canonical;
  } else if (!canonical.startsWith('+') && canonical.length === 10) {
    canonical = '+91' + canonical;
  }

  const e164Regex = /^\+[1-9]\d{6,14}$/;
  const isValid = e164Regex.test(canonical);

  let formatted = canonical;
  if (canonical.startsWith('+91') && canonical.length === 13) {
    formatted = '+91 ' + canonical.slice(3, 8) + ' ' + canonical.slice(8);
  }

  const cleanDigits = canonical.replace(/\D/g, '');

  return {
    isValid,
    formatted: isValid ? formatted : raw,
    canonical: isValid ? canonical : raw,
    cleanDigits: cleanDigits,
    reason: isValid ? 'Valid international E.164 format' : 'Invalid number format. Expected format: +91 98765 43210'
  };
}

// Send genuine outbound message via Meta WhatsApp Business Cloud API v20.0
async function sendViaMetaCloudAPI(cleanDigits, messageText, options = {}) {
  const token = currentConfig.api_token || process.env.META_WHATSAPP_TOKEN;
  const phoneId = currentConfig.phone_number_id || process.env.META_PHONE_NUMBER_ID;

  if (!token || !phoneId) {
    return {
      success: false,
      mode: 'unconfigured',
      error: 'WhatsApp Cloud API credentials not configured. Please enter your Meta System User Access Token and Phone Number ID in Admin Settings or .env file.'
    };
  }

  const attachment = options.attachment || null;
  const templateName = options.template_name || null;
  const templateComponents = options.template_components || null;
  const languageCode = options.language_code || 'en';
  const metaUrl = `https://graph.facebook.com/v20.0/${phoneId}/messages`;

  let metaPayload = null;

  // 1. Template-based message dispatch (Required for outbound business-initiated messages outside 24h window)
  if (templateName && options.send_as_template) {
    metaPayload = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: cleanDigits,
      type: 'template',
      template: {
        name: templateName,
        language: { code: languageCode },
        components: templateComponents || []
      }
    };
  }
  // 2. Media / Document attachment message
  else if (attachment && (attachment.dataUrl || attachment.previewUrl || (typeof attachment === 'string' && attachment.startsWith('http')))) {
    const mediaUrl = typeof attachment === 'string' ? attachment : (attachment.dataUrl || attachment.previewUrl);
    const isPdf = (attachment.type === 'document') || (attachment.name && attachment.name.toLowerCase().endsWith('.pdf')) || mediaUrl.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      metaPayload = {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: cleanDigits,
        type: 'document',
        document: {
          link: mediaUrl,
          filename: attachment.name || 'Golden_Kids_Notice.pdf',
          caption: messageText || 'Golden Kids School Document'
        }
      };
    } else {
      metaPayload = {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: cleanDigits,
        type: 'image',
        image: {
          link: mediaUrl,
          caption: messageText || 'Golden Kids School Announcement'
        }
      };
    }
  }
  // 3. Standard text message payload
  else {
    metaPayload = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: cleanDigits,
      type: 'text',
      text: {
        preview_url: false,
        body: messageText
      }
    };
  }

  try {
    console.log(`[WhatsApp Backend] Sending to ${cleanDigits} via Meta Cloud API (${metaPayload.type})...`);
    const resp = await fetch(metaUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(metaPayload)
    });

    const data = await resp.json();

    if (!resp.ok) {
      const metaErr = data.error || {};
      const errMsg = metaErr.message || 'Meta Cloud API dispatch failed';
      const errCode = metaErr.code || resp.status;
      const errSubcode = metaErr.error_subcode;
      const userMsg = metaErr.error_user_msg || metaErr.error_user_title || errMsg;

      console.error(`[WhatsApp Backend] Meta Cloud API Error [${errCode}]:`, errMsg, data);

      return {
        success: false,
        mode: 'cloud_api_error',
        error: errMsg,
        user_message: userMsg,
        code: errCode,
        subcode: errSubcode,
        details: data
      };
    }

    const providerMsgId = data.messages?.[0]?.id || ('wamid.' + Date.now());
    console.log(`[WhatsApp Backend] Message successfully accepted by Meta! Message ID: ${providerMsgId}`);

    return {
      success: true,
      mode: 'cloud_api',
      provider_message_id: providerMsgId,
      raw: data
    };
  } catch (err) {
    console.error('[WhatsApp Backend] Network error during Meta API request:', err);
    return {
      success: false,
      mode: 'network_error',
      error: 'Network connection to Meta Graph API failed: ' + err.message
    };
  }
}

// Process a single dispatch request
export async function dispatchSingleWhatsAppMessage(payload) {
  const phoneVal = validatePhoneNumber(payload.phone_number || payload.to || payload.recipient_phone || payload.phone);
  const messageText = payload.content || payload.message || payload.rendered_content || '';

  if (!phoneVal.isValid) {
    const failedRecord = {
      id: payload.message_id || ('wmsg-' + Date.now() + '-' + Math.floor(Math.random() * 1000)),
      student_id: payload.student_id || null,
      student_name: payload.student_name || 'Student',
      parent_name: payload.parent_name || 'Parent/Guardian',
      phone_number: payload.phone_number || 'Missing Number',
      canonical_phone: '',
      message_type: payload.message_type || 'general',
      template_name: payload.template_name || 'Direct Notice',
      rendered_content: messageText,
      media_type: payload.attachment ? payload.attachment.type : null,
      media_name: payload.attachment ? payload.attachment.name : null,
      media_size: payload.attachment ? payload.attachment.sizeFormatted : null,
      media_url: payload.attachment ? (payload.attachment.dataUrl || payload.attachment.previewUrl) : null,
      status: 'failed',
      error_code: 'INVALID_PHONE_NUMBER',
      error_message: phoneVal.reason,
      provider_message_id: null,
      created_at: new Date().toISOString(),
      sent_at: null,
      delivered_at: null,
      read_at: null
    };
    messageStore.unshift(failedRecord);
    saveMessagesToDisk();
    return { success: false, mode: 'invalid_phone', error: phoneVal.reason, message: failedRecord };
  }

  const sendOptions = {
    attachment: payload.attachment || null,
    template_name: payload.template_name || null,
    template_components: payload.template_components || null,
    language_code: payload.language_code || 'en',
    send_as_template: Boolean(payload.send_as_template || payload.is_template)
  };

  // Send genuinely via Meta Cloud API
  const metaResult = await sendViaMetaCloudAPI(phoneVal.cleanDigits, messageText, sendOptions);

  const status = metaResult.success ? 'sent' : 'failed';
  const providerId = metaResult.provider_message_id || null;

  const record = {
    id: payload.message_id || ('wmsg-' + Date.now() + '-' + Math.floor(Math.random() * 1000)),
    student_id: payload.student_id || null,
    student_name: payload.student_name || 'Student',
    parent_name: payload.parent_name || 'Parent/Guardian',
    phone_number: phoneVal.formatted,
    canonical_phone: phoneVal.canonical,
    message_type: payload.message_type || 'general',
    template_name: payload.template_name || 'Direct Notice',
    rendered_content: messageText,
    media_type: sendOptions.attachment ? sendOptions.attachment.type : null,
    media_name: sendOptions.attachment ? sendOptions.attachment.name : null,
    media_size: sendOptions.attachment ? sendOptions.attachment.sizeFormatted : null,
    media_url: sendOptions.attachment ? (sendOptions.attachment.dataUrl || sendOptions.attachment.previewUrl) : null,
    status: status,
    provider_message_id: providerId,
    error_code: metaResult.code || (metaResult.error ? (metaResult.mode === 'unconfigured' ? 'UNCONFIGURED_CREDENTIALS' : 'DISPATCH_ERROR') : null),
    error_message: metaResult.error || null,
    created_at: new Date().toISOString(),
    sent_at: status === 'sent' ? new Date().toISOString() : null,
    delivered_at: null,
    read_at: null
  };

  messageStore.unshift(record);
  saveMessagesToDisk();

  return {
    success: metaResult.success,
    mode: metaResult.mode,
    messageId: record.id,
    provider_message_id: providerId,
    status: record.status,
    error: metaResult.error || null,
    user_message: metaResult.user_message || metaResult.error || null,
    recipient: record.phone_number,
    record: record
  };
}

// Router handler for all WhatsApp API endpoints
export async function handleWhatsAppApiRequest(req, res, parsedUrl) {
  const pathname = parsedUrl.pathname;
  const method = req.method.toUpperCase();

  // Helper response sender
  const sendJSON = (statusCode, data) => {
    const bodyStr = JSON.stringify(data);
    res.writeHead(statusCode, {
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': Buffer.byteLength(bodyStr),
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-requested-with',
      'Cache-Control': 'no-cache, no-store, must-revalidate'
    });
    res.end(bodyStr);
  };

  // Handle CORS preflight
  if (method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-requested-with'
    });
    res.end();
    return;
  }

  // Parse JSON body for POST requests
  let reqBody = {};
  if (method === 'POST') {
    try {
      const buffers = [];
      for await (const chunk of req) {
        buffers.push(chunk);
      }
      const rawText = Buffer.concat(buffers).toString('utf8');
      if (rawText.trim()) {
        reqBody = JSON.parse(rawText);
      }
    } catch (e) {
      return sendJSON(400, { success: false, error: 'Invalid JSON request body: ' + e.message });
    }
  }

  // 1. Send Single Direct WhatsApp Message
  // POST /api/whatsapp/send
  if (pathname === '/api/whatsapp/send' && method === 'POST') {
    try {
      const result = await dispatchSingleWhatsAppMessage(reqBody);
      const httpCode = result.success ? 200 : (result.mode === 'unconfigured' ? 400 : (result.mode === 'invalid_phone' ? 400 : 502));
      return sendJSON(httpCode, result);
    } catch (err) {
      return sendJSON(500, { success: false, error: err.message });
    }
  }

  // 2. Broadcast Batch WhatsApp Messages with Throttling
  // POST /api/whatsapp/broadcast
  if (pathname === '/api/whatsapp/broadcast' && method === 'POST') {
    try {
      const recipients = Array.isArray(reqBody.recipients) ? reqBody.recipients : [];
      const templateName = reqBody.template_name || 'Broadcast Circular';
      const attachment = reqBody.attachment || null;
      const messageType = reqBody.message_type || 'announcement';

      if (!recipients.length) {
        return sendJSON(400, { success: false, error: 'No recipients provided for broadcast' });
      }

      const results = [];
      let successCount = 0;
      let failedCount = 0;

      for (let i = 0; i < recipients.length; i++) {
        const r = recipients[i];
        const payload = {
          phone_number: r.phone_number || r.parent_whatsapp || r.parent_phone,
          student_id: r.student_id || r.id,
          student_name: r.student_name || r.full_name,
          parent_name: r.parent_name,
          content: r.content || reqBody.content || '',
          template_name: templateName,
          template_components: r.template_components || reqBody.template_components || null,
          send_as_template: reqBody.send_as_template || false,
          message_type: messageType,
          attachment: attachment
        };

        const resItem = await dispatchSingleWhatsAppMessage(payload);
        results.push(resItem);
        if (resItem.success) successCount++;
        else failedCount++;

        // Throttling delay (50ms) between dispatches to maintain clean carrier rate compliance
        if (i < recipients.length - 1) {
          await new Promise(res => setTimeout(res, 50));
        }
      }

      return sendJSON(200, {
        success: successCount > 0,
        total: recipients.length,
        dispatched: successCount,
        failed: failedCount,
        results: results
      });
    } catch (err) {
      return sendJSON(500, { success: false, error: err.message });
    }
  }

  // 3. Status & Health Check
  // GET /api/whatsapp/status or GET /api/whatsapp/health
  if ((pathname === '/api/whatsapp/status' || pathname === '/api/whatsapp/health') && method === 'GET') {
    const isLive = Boolean(currentConfig.api_token && currentConfig.phone_number_id);
    return sendJSON(200, {
      success: true,
      provider: currentConfig.provider || 'cloud_api',
      is_connected: isLive,
      environment: isLive ? 'production' : 'unconfigured',
      business_phone: currentConfig.business_phone,
      business_account_id: currentConfig.business_account_id,
      phone_number_id: currentConfig.phone_number_id,
      has_token: Boolean(currentConfig.api_token),
      total_messages_logged: messageStore.length,
      last_tested_at: currentConfig.last_tested_at
    });
  }

  // 4. Test API Connection Handshake with Meta Graph API
  // POST /api/whatsapp/test
  if (pathname === '/api/whatsapp/test' && method === 'POST') {
    const token = reqBody.api_token || currentConfig.api_token || process.env.META_WHATSAPP_TOKEN;
    const phoneId = reqBody.phone_number_id || currentConfig.phone_number_id || process.env.META_PHONE_NUMBER_ID;

    if (!token || !phoneId) {
      return sendJSON(400, {
        success: false,
        status: 'unconfigured',
        error: 'Meta WhatsApp Business API credentials not configured. Enter your Meta System User Access Token and Phone Number ID to enable live message delivery.'
      });
    }

    try {
      const testUrl = `https://graph.facebook.com/v20.0/${phoneId}?access_token=${encodeURIComponent(token)}`;
      console.log(`[WhatsApp Backend] Handshake verification test for Phone ID ${phoneId}...`);
      const resp = await fetch(testUrl);
      const data = await resp.json();

      if (resp.ok && data.id) {
        currentConfig.is_connected = true;
        currentConfig.last_tested_at = new Date().toISOString();
        if (data.display_phone_number) currentConfig.business_phone = data.display_phone_number;
        saveConfigToDisk();

        return sendJSON(200, {
          success: true,
          status: 'connected',
          verified_name: data.verified_name || 'Golden Kids School',
          display_phone_number: data.display_phone_number || currentConfig.business_phone,
          quality_rating: data.quality_rating || 'UNKNOWN',
          account_mode: data.account_mode || 'LIVE',
          message: `Official Meta Cloud API verified successfully! Display Name: ${data.verified_name || data.display_phone_number || 'Golden Kids School'}`
        });
      } else {
        const errorMsg = data.error?.message || 'Failed to authenticate Meta Phone Number ID / Access Token.';
        return sendJSON(400, {
          success: false,
          status: 'error',
          code: data.error?.code,
          error: errorMsg,
          details: data
        });
      }
    } catch (e) {
      return sendJSON(500, {
        success: false,
        status: 'network_error',
        error: 'Could not connect to Meta Graph API: ' + e.message
      });
    }
  }

  // 5. Sync Templates with Meta Business Manager
  // GET /api/whatsapp/templates/meta
  if (pathname === '/api/whatsapp/templates/meta' && method === 'GET') {
    const token = currentConfig.api_token || process.env.META_WHATSAPP_TOKEN;
    const wabaId = currentConfig.business_account_id || process.env.META_WABA_ID;

    if (!token || !wabaId) {
      return sendJSON(400, {
        success: false,
        error: 'Meta WABA Account ID and Access Token are required to fetch message templates from Meta.'
      });
    }

    try {
      const url = `https://graph.facebook.com/v20.0/${wabaId}/message_templates?access_token=${encodeURIComponent(token)}&limit=100`;
      const resp = await fetch(url);
      const data = await resp.json();

      if (resp.ok && Array.isArray(data.data)) {
        return sendJSON(200, {
          success: true,
          count: data.data.length,
          templates: data.data
        });
      } else {
        return sendJSON(400, {
          success: false,
          error: data.error?.message || 'Failed to fetch templates from Meta Business Manager',
          details: data
        });
      }
    } catch (e) {
      return sendJSON(500, { success: false, error: e.message });
    }
  }

  // 6. Get / Save WhatsApp Configuration
  // GET /api/whatsapp/config
  if (pathname === '/api/whatsapp/config' && method === 'GET') {
    const sanitized = {
      ...currentConfig,
      api_token: currentConfig.api_token ? (currentConfig.api_token.slice(0, 8) + '••••••••' + currentConfig.api_token.slice(-4)) : ''
    };
    return sendJSON(200, { success: true, config: sanitized });
  }

  // POST /api/whatsapp/config
  if (pathname === '/api/whatsapp/config' && method === 'POST') {
    if (reqBody.business_phone) currentConfig.business_phone = reqBody.business_phone.trim();
    if (reqBody.business_account_id) currentConfig.business_account_id = reqBody.business_account_id.trim();
    if (reqBody.phone_number_id) currentConfig.phone_number_id = reqBody.phone_number_id.trim();
    if (reqBody.api_token !== undefined && !reqBody.api_token.includes('••••')) {
      currentConfig.api_token = reqBody.api_token.trim();
    }
    if (reqBody.webhook_verify_token) currentConfig.webhook_verify_token = reqBody.webhook_verify_token.trim();
    if (reqBody.environment) currentConfig.environment = reqBody.environment;
    if (reqBody.rate_limit_per_second) currentConfig.rate_limit_per_second = parseInt(reqBody.rate_limit_per_second, 10);
    if (reqBody.daily_quota) currentConfig.daily_quota = parseInt(reqBody.daily_quota, 10);

    currentConfig.is_connected = Boolean(currentConfig.api_token && currentConfig.phone_number_id);
    saveConfigToDisk();

    return sendJSON(200, {
      success: true,
      message: 'WhatsApp API configuration saved successfully',
      is_connected: currentConfig.is_connected
    });
  }

  // 7. Message Delivery Ledger
  // GET /api/whatsapp/messages
  if (pathname === '/api/whatsapp/messages' && method === 'GET') {
    const statusFilter = parsedUrl.searchParams.get('status');
    const limit = parseInt(parsedUrl.searchParams.get('limit') || '100', 10);

    let list = messageStore;
    if (statusFilter && statusFilter !== 'all') {
      list = list.filter(m => m.status === statusFilter);
    }
    return sendJSON(200, { success: true, count: list.length, messages: list.slice(0, limit) });
  }

  // 8. Webhook Receiver (Meta WhatsApp Webhook Callback)
  // GET/POST /api/whatsapp/webhook
  if (pathname === '/api/whatsapp/webhook') {
    // Webhook verification challenge (GET)
    if (method === 'GET') {
      const mode = parsedUrl.searchParams.get('hub.mode');
      const token = parsedUrl.searchParams.get('hub.verify_token');
      const challenge = parsedUrl.searchParams.get('hub.challenge');

      if (mode === 'subscribe' && token === currentConfig.webhook_verify_token) {
        console.log('[WhatsApp Webhook] Verification challenge passed successfully');
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(challenge);
        return;
      }
      console.warn('[WhatsApp Webhook] Verification challenge failed. Invalid token.');
      return sendJSON(403, { error: 'Verification challenge failed' });
    }

    // Webhook incoming delivery receipts (POST)
    if (method === 'POST') {
      try {
        const entries = reqBody.entry ?? [];
        for (const entry of entries) {
          const changes = entry.changes ?? [];
          for (const change of changes) {
            const value = change.value;
            if (!value) continue;
            const statuses = value.statuses ?? [];
            for (const st of statuses) {
              const providerMsgId = st.id;
              const statusStr = st.status; // 'sent' | 'delivered' | 'read' | 'failed'
              const ts = st.timestamp ? new Date(parseInt(st.timestamp) * 1000).toISOString() : new Date().toISOString();

              console.log(`[WhatsApp Webhook] Delivery status update for ${providerMsgId}: ${statusStr}`);
              const msg = messageStore.find(m => m.provider_message_id === providerMsgId);
              if (msg) {
                msg.status = statusStr;
                if (statusStr === 'delivered') msg.delivered_at = ts;
                if (statusStr === 'read') msg.read_at = ts;
                if (statusStr === 'failed') {
                  const err = st.errors?.[0];
                  msg.error_code = err?.code?.toString() || 'DELIVERY_FAILED';
                  msg.error_message = err?.title || err?.message || 'Carrier delivery failed';
                }
              }
            }
          }
        }
        saveMessagesToDisk();
        return sendJSON(200, { success: true });
      } catch (err) {
        console.error('[WhatsApp Webhook] Error processing incoming receipt:', err);
        return sendJSON(500, { error: err.message });
      }
    }
  }

  // Route not found in WhatsApp API
  return sendJSON(404, { success: false, error: 'Endpoint not found in WhatsApp Backend API' });
}
