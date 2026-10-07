// Supabase Edge Function: whatsapp-send
// Official Meta WhatsApp Cloud API Outbound Dispatcher
// Endpoint: POST /functions/v1/whatsapp-send

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SendPayload {
  message_id?: string;
  recipient_phone: string;
  template_name: string;
  language_code?: string;
  variables?: Record<string, string>;
  components?: Array<any>;
  message_type?: string;
  student_id?: string;
  recipient_parent_id?: string;
  automation_id?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const metaApiToken = Deno.env.get("META_WHATSAPP_TOKEN") ?? "";
    const phoneNumberId = Deno.env.get("META_PHONE_NUMBER_ID") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify authenticated user
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Parse request payload
    const payload: SendPayload = await req.json();
    const { recipient_phone, template_name, language_code = "en", variables = {}, message_id } = payload;

    if (!recipient_phone || !template_name) {
      return new Response(JSON.stringify({ error: "Missing recipient_phone or template_name" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Clean and validate E.164 phone number
    const cleanPhone = recipient_phone.replace(/[^0-9]/g, "");
    if (cleanPhone.length < 10) {
      return new Response(JSON.stringify({ error: "Invalid E.164 recipient phone number" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check if live Meta credentials are configured
    if (!metaApiToken || !phoneNumberId) {
      // Demo / Unconnected Mode: Record as queued/demo without claiming fake provider delivery
      return new Response(
        JSON.stringify({
          status: "demo_mode",
          message: "WhatsApp is not connected. Meta API credentials are not set in environment.",
          recipient: cleanPhone,
          template: template_name,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Build Meta Cloud API request body
    const metaUrl = `https://graph.facebook.com/v19.0/${phoneNumberId}/messages`;
    const metaBody = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: cleanPhone,
      type: "template",
      template: {
        name: template_name,
        language: { code: language_code },
        components: payload.components ?? [],
      },
    };

    const metaResponse = await fetch(metaUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${metaApiToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(metaBody),
    });

    const metaData = await metaResponse.json();

    if (!metaResponse.ok) {
      const errorMsg = metaData.error?.message || "WhatsApp provider dispatch error";
      if (message_id) {
        await supabase
          .from("whatsapp_messages")
          .update({
            status: "failed",
            error_code: metaData.error?.code?.toString() || "API_ERROR",
            error_message: errorMsg,
            updated_at: new Date().toISOString(),
          })
          .eq("id", message_id);
      }

      return new Response(JSON.stringify({ error: errorMsg, details: metaData }), {
        status: metaResponse.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const providerMsgId = metaData.messages?.[0]?.id;

    // Update message status in Supabase
    if (message_id) {
      await supabase
        .from("whatsapp_messages")
        .update({
          status: "sent",
          provider_message_id: providerMsgId,
          sent_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", message_id);
    }

    return new Response(
      JSON.stringify({
        status: "sent",
        provider_message_id: providerMsgId,
        recipient: cleanPhone,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
