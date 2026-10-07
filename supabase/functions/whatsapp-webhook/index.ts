// Supabase Edge Function: whatsapp-webhook
// Official Meta WhatsApp Webhook Receiver & Status Callback Processor
// Endpoint: GET/POST /functions/v1/whatsapp-webhook

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const url = new URL(req.url);

  // 1. Meta Webhook Verification Challenge (GET)
  if (req.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");

    const expectedVerifyToken = Deno.env.get("WHATSAPP_WEBHOOK_VERIFY_TOKEN") || "goldenkids_webhook_verify_2026";

    if (mode === "subscribe" && token === expectedVerifyToken) {
      return new Response(challenge, { status: 200 });
    } else {
      return new Response("Verification failed", { status: 403 });
    }
  }

  // 2. Inbound Webhook Event Callback (POST)
  if (req.method === "POST") {
    try {
      const body = await req.json();

      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      const supabase = createClient(supabaseUrl, supabaseServiceKey);

      // Process Meta WhatsApp status updates
      const entries = body.entry ?? [];
      for (const entry of entries) {
        const changes = entry.changes ?? [];
        for (const change of changes) {
          const value = change.value;
          if (!value) continue;

          // Process message status receipts: sent, delivered, read, failed
          const statuses = value.statuses ?? [];
          for (const st of statuses) {
            const providerMsgId = st.id;
            const statusStr = st.status; // 'sent' | 'delivered' | 'read' | 'failed'
            const timestamp = st.timestamp ? new Date(parseInt(st.timestamp) * 1000).toISOString() : new Date().toISOString();

            const updatePayload: Record<string, any> = {
              status: statusStr,
              updated_at: new Date().toISOString(),
            };

            if (statusStr === "delivered") {
              updatePayload.delivered_at = timestamp;
            } else if (statusStr === "read") {
              updatePayload.read_at = timestamp;
            } else if (statusStr === "failed") {
              const errors = st.errors ?? [];
              const firstErr = errors[0];
              updatePayload.error_code = firstErr?.code?.toString() || "UNKNOWN";
              updatePayload.error_message = firstErr?.title || firstErr?.message || "Delivery failed";
            }

            // Update matching message record
            if (providerMsgId) {
              await supabase
                .from("whatsapp_messages")
                .update(updatePayload)
                .eq("provider_message_id", providerMsgId);
            }
          }
        }
      }

      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  return new Response("Method Not Allowed", { status: 405 });
});
