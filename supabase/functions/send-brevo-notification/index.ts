// Supabase Edge Function: send-brevo-notification
// Deploy dengan:
//   supabase secrets set BREVO_API_KEY=xkeysib-... BREVO_SENDER_EMAIL=noreply@domainanda.com
//   supabase functions deploy send-brevo-notification
//
// Menjamin pengiriman notifikasi email via Brevo API tanpa CORS issue di Flutter Web
// serta mencegah duplikasi notifikasi melalui constraint UNIQUE(user_id, event_dedup_key).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface NotificationPayload {
  user_id: string;
  recipient_email?: string;
  recipient_name?: string;
  trip_id?: string;
  train_number?: string;
  train_name?: string;
  event_type:
    | "TRAIN_DELAY"
    | "SCHEDULE_CHANGE"
    | "SERVICE_DISRUPTION"
    | "ARRIVAL_INFO"
    | "TRIP_STATUS_CHANGE";
  event_dedup_key: string;
  title: string;
  message: string;
  send_email?: boolean;
  metadata?: Record<string, unknown>;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: NotificationPayload = await req.json();

    if (!payload.user_id || !payload.event_dedup_key || !payload.event_type || !payload.title) {
      return new Response(
        JSON.stringify({ error: "Missing required fields (user_id, event_dedup_key, event_type, title)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const brevoApiKey = Deno.env.get("BREVO_API_KEY") ?? "";
    const senderEmail = Deno.env.get("BREVO_SENDER_EMAIL") ?? "noreply@tka-rail.id";
    const senderName = Deno.env.get("BREVO_SENDER_NAME") ?? "TKA Rail Tracking";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Atomic Deduplication Insert into Postgres
    const { data: inserted, error: insertError } = await supabase
      .from("train_notifications")
      .insert({
        user_id: payload.user_id,
        recipient_email: payload.recipient_email ?? null,
        trip_id: payload.trip_id ?? null,
        train_number: payload.train_number ?? null,
        train_name: payload.train_name ?? null,
        event_type: payload.event_type,
        event_dedup_key: payload.event_dedup_key,
        title: payload.title,
        message: payload.message,
        metadata: payload.metadata ?? {},
        brevo_status: payload.send_email && payload.recipient_email ? "PENDING" : "SKIPPED",
      })
      .select()
      .single();

    if (insertError) {
      // PostgreSQL unique violation code 23505 => DUPLICATE EVENT DETECTED
      if (insertError.code === "23505") {
        return new Response(
          JSON.stringify({
            status: "duplicate_ignored",
            message: "Notifikasi untuk kejadian yang sama sudah pernah dikirim sebelumnya.",
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      throw insertError;
    }

    // 2. Dispatch email via Brevo Transactional API if enabled
    let brevoStatus = "SKIPPED";
    let brevoMessageId: string | null = null;
    let brevoError: string | null = null;

    if (payload.send_email !== false && payload.recipient_email && brevoApiKey) {
      const brevoResp = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          "accept": "application/json",
          "api-key": brevoApiKey,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          sender: { name: senderName, email: senderEmail },
          to: [{ email: payload.recipient_email, name: payload.recipient_name ?? "Penumpang TKA" }],
          subject: `[TKA Info] ${payload.title}`,
          htmlContent: `
            <div style="font-family:Segoe UI,Arial,sans-serif;max-width:560px;margin:auto;border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;">
              <div style="background:#062056;color:#ffffff;padding:18px 24px;">
                <h2 style="margin:0;font-size:18px;">TKA Rail Live Tracking</h2>
                <p style="margin:4px 0 0;font-size:12px;opacity:0.85;">${payload.event_type.replaceAll("_", " ")}</p>
              </div>
              <div style="padding:20px 24px;color:#1e293b;">
                <h3 style="margin-top:0;color:#062056;">${payload.title}</h3>
                <p style="line-height:1.6;">${payload.message}</p>
                ${
                  payload.train_name
                    ? `<p style="background:#f8fafc;padding:12px;border-radius:8px;font-size:13px;">
                        <strong>Kereta:</strong> ${payload.train_name} (${payload.train_number ?? "-"})
                      </p>`
                    : ""
                }
                <p style="font-size:11px;color:#64748b;margin-top:20px;">
                  Notifikasi otomatis dari sistem TKA Rail Indonesia. Dedup Key: ${payload.event_dedup_key}
                </p>
              </div>
            </div>
          `,
        }),
      });

      const brevoJson = await brevoResp.json().catch(() => ({}));
      if (brevoResp.ok) {
        brevoStatus = "SENT";
        brevoMessageId = brevoJson.messageId ?? null;
      } else {
        brevoStatus = "FAILED";
        brevoError = JSON.stringify(brevoJson);
      }

      await supabase
        .from("train_notifications")
        .update({
          brevo_status: brevoStatus,
          brevo_message_id: brevoMessageId,
          brevo_error: brevoError,
        })
        .eq("id", inserted.id);
    }

    return new Response(
      JSON.stringify({
        status: "ok",
        notification_id: inserted.id,
        brevo_status: brevoStatus,
        brevo_message_id: brevoMessageId,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

