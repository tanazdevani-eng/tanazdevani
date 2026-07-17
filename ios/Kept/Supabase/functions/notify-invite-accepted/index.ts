// Supabase Edge Function: sends an APNs push to an inviter when someone accepts their
// Circle invite. Runs with the service role key so it can read push_tokens across users
// (RLS on that table is owner-only from the client) — same reasoning as delete-account.
//
// Deploy: supabase functions deploy notify-invite-accepted
//
// Requires four secrets, set once via `supabase secrets set NAME=value`:
//   APNS_KEY         contents of the .p8 key file from Apple Developer -> Certificates,
//                    Identifiers & Profiles -> Keys -> (your APNs key) -> download.
//                    Paste the whole file including the BEGIN/END PRIVATE KEY lines.
//   APNS_KEY_ID      the 10-character Key ID shown next to that key.
//   APNS_TEAM_ID     your Apple Developer Team ID (App Store Connect -> Membership).
//   APNS_BUNDLE_ID   com.kept.app, or your real bundle id if you changed it.
//
// One APNs key works for this and any future push feature — no need to make a new one
// per notification type. Uses the production APNs host, which is what TestFlight and
// App Store builds both talk to; only an un-archived Xcode Debug run would need the
// sandbox host (api.sandbox.push.apple.com) instead, not relevant once you're testing
// via TestFlight.

import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

Deno.serve(async (req) => {
  let body: { inviter_id?: string; accepter_name?: string };
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  const { inviter_id, accepter_name } = body;
  if (!inviter_id || !accepter_name) {
    return new Response("Missing inviter_id or accepter_name", { status: 400 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: tokens, error } = await adminClient
    .from("push_tokens")
    .select("device_token")
    .eq("user_id", inviter_id);

  if (error) {
    return new Response(error.message, { status: 500 });
  }
  if (!tokens || tokens.length === 0) {
    // Not an error — the inviter just doesn't have a registered device (never granted
    // notification permission, or hasn't opened the app since this feature shipped).
    return new Response(JSON.stringify({ sent: 0 }), { headers: { "Content-Type": "application/json" } });
  }

  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const bundleId = Deno.env.get("APNS_BUNDLE_ID")!;
  const privateKeyPem = Deno.env.get("APNS_KEY")!.replace(/\\n/g, "\n");

  const privateKey = await importPKCS8(privateKeyPem, "ES256");
  const providerToken = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuedAt()
    .setIssuer(teamId)
    .sign(privateKey);

  const payload = {
    aps: {
      alert: {
        title: "New in your Circle",
        body: `${accepter_name} accepted your invite.`,
      },
      sound: "default",
    },
  };

  let sent = 0;
  for (const { device_token } of tokens) {
    const response = await fetch(`https://api.push.apple.com/3/device/${device_token}`, {
      method: "POST",
      headers: {
        "authorization": `bearer ${providerToken}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      body: JSON.stringify(payload),
    });
    if (response.ok) sent += 1;
  }

  return new Response(JSON.stringify({ sent }), { headers: { "Content-Type": "application/json" } });
});
