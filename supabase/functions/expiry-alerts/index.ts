// PTN Team Tracker — daily expiration + birthday alerts.
// Called once a day by pg_cron (see add_email_alerts.sql). Sends one email
// (Resend) and, if Twilio is configured, one text message listing anything
// that newly entered its alert window. Each item is announced only once,
// tracked in the alert_log table.
//
// Secrets (Supabase > Edge Functions > Secrets):
//   CRON_SECRET          required — must match the value in add_email_alerts.sql
//   RESEND_API_KEY       required
//   ALERT_EMAIL_TO       optional — default om@physicaltherapynow.com
//   ALERT_EMAIL_FROM     optional — default "PTN Team Tracker <onboarding@resend.dev>"
//   TWILIO_ACCOUNT_SID   optional — SMS is skipped unless all three are set
//   TWILIO_AUTH_TOKEN
//   TWILIO_FROM          e.g. +14075551234 (your Twilio number)
//   ALERT_SMS_TO         e.g. +14075556789 (comma-separated for several)

const LICENSE_ALERT_DAYS = 60;
const BIRTHDAY_ALERT_DAYS = 10;
const TIME_ZONE = "America/New_York";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Prefer the new-style secret key (sb_secret_…) when the project has one: it
// isn't a JWT, so it can't hit "JWT issued at future" clock-skew errors.
// It goes in the apikey header only; the legacy JWT also needs Authorization.
const SECRET_KEY: string | undefined = (() => {
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
    return keys.default || Object.values(keys)[0];
  } catch { return undefined; }
})();
const AUTH_HEADERS: Record<string, string> = SECRET_KEY
  ? { apikey: SECRET_KEY }
  : { apikey: SERVICE_KEY, Authorization: "Bearer " + SERVICE_KEY };

type Alert = { kind: string; refId: string; targetDate: string; title: string; detail: string; days: number };

async function db(path: string, init: RequestInit = {}) {
  for (let attempt = 1; ; attempt++) {
    const res = await fetch(SUPABASE_URL + "/rest/v1/" + path, {
      ...init,
      headers: { ...AUTH_HEADERS, "Content-Type": "application/json", ...(init.headers || {}) },
    });
    if (res.ok) return res.status === 204 || res.status === 201 ? null : res.json();
    const text = await res.text();
    // A freshly minted JWT can look a few seconds "in the future" to PostgREST.
    if (res.status === 401 && text.includes("PGRST303") && attempt < 4) {
      await new Promise((r) => setTimeout(r, 3000 * attempt));
      continue;
    }
    throw new Error(path + ": " + res.status + " " + text);
  }
}

// Dates are handled as plain YYYY-MM-DD in Florida time, like the app does.
function todayISO() {
  return new Intl.DateTimeFormat("en-CA", { timeZone: TIME_ZONE, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
}
function toUTC(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return Date.UTC(y, m - 1, d);
}
function iso(ms: number) {
  return new Date(ms).toISOString().slice(0, 10);
}
function daysBetween(fromISO: string, toISO: string) {
  return Math.round((toUTC(toISO) - toUTC(fromISO)) / 86400000);
}
function nextBirthday(birthday: string, today: string) {
  const [, m, d] = birthday.split("-").map(Number);
  const year = Number(today.slice(0, 4));
  const thisYear = iso(Date.UTC(year, m - 1, d));
  return thisYear < today ? iso(Date.UTC(year + 1, m - 1, d)) : thisYear;
}
function fmt(s: string) {
  const [y, m, d] = s.split("-");
  return m + "/" + d + "/" + y;
}
function esc(s: string) {
  return String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));
}
function whenText(a: Alert) {
  if (a.kind === "birthday") return a.days === 0 ? "today" : "in " + a.days + (a.days === 1 ? " day" : " days");
  if (a.days < 0) return "EXPIRED " + -a.days + (a.days === -1 ? " day ago" : " days ago");
  return a.days === 0 ? "expires today" : "expires in " + a.days + (a.days === 1 ? " day" : " days");
}

async function collectAlerts(today: string): Promise<Alert[]> {
  const [providers, clinicLicenses, employees] = await Promise.all([
    db("providers?select=id,person_name,occupation,license_number,expiration_date&expiration_date=not.is.null"),
    db("clinic_licenses?select=id,clinic,license_type,license_number,expiration_date&expiration_date=not.is.null"),
    db("employees?select=id,name,clinic,birthday&status=eq.Active&birthday=not.is.null"),
  ]);
  const alerts: Alert[] = [];
  for (const p of providers) {
    const days = daysBetween(today, p.expiration_date);
    if (days <= LICENSE_ALERT_DAYS) alerts.push({
      kind: "provider", refId: p.id, targetDate: p.expiration_date, days,
      title: p.person_name + " — " + p.occupation + " license",
      detail: (p.license_number ? "#" + p.license_number + " · " : "") + "expires " + fmt(p.expiration_date),
    });
  }
  for (const l of clinicLicenses) {
    const days = daysBetween(today, l.expiration_date);
    if (days <= LICENSE_ALERT_DAYS) alerts.push({
      kind: "clinic_license", refId: l.id, targetDate: l.expiration_date, days,
      title: l.clinic + " — " + l.license_type,
      detail: (l.license_number ? "#" + l.license_number + " · " : "") + "expires " + fmt(l.expiration_date),
    });
  }
  for (const e of employees) {
    const next = nextBirthday(e.birthday, today);
    const days = daysBetween(today, next);
    if (days <= BIRTHDAY_ALERT_DAYS) alerts.push({
      kind: "birthday", refId: e.id, targetDate: next, days,
      title: e.name + " (" + e.clinic + ")",
      detail: "birthday " + fmt(next).slice(0, 5),
    });
  }
  return alerts;
}

async function dropAlreadySent(alerts: Alert[]) {
  if (!alerts.length) return alerts;
  const sent: { kind: string; ref_id: string; target_date: string }[] = await db("alert_log?select=kind,ref_id,target_date");
  const seen = new Set(sent.map((r) => r.kind + "|" + r.ref_id + "|" + r.target_date));
  return alerts.filter((a) => !seen.has(a.kind + "|" + a.refId + "|" + a.targetDate));
}

function buildEmail(alerts: Alert[]) {
  const licenses = alerts.filter((a) => a.kind !== "birthday").sort((a, b) => a.days - b.days);
  const birthdays = alerts.filter((a) => a.kind === "birthday").sort((a, b) => a.days - b.days);
  const row = (a: Alert) => {
    const color = a.kind === "birthday" ? "#1f7d76" : a.days < 0 ? "#df4a40" : "#d99425";
    return "<tr><td style='padding:8px 10px;border-bottom:1px solid #e2ebe9;'><b>" + esc(a.title) + "</b><br><span style='color:#73847f;font-size:13px;'>" +
      esc(a.detail) + "</span></td><td style='padding:8px 10px;border-bottom:1px solid #e2ebe9;color:" + color + ";font-weight:700;white-space:nowrap;'>" +
      esc(whenText(a)) + "</td></tr>";
  };
  const section = (title: string, list: Alert[]) => list.length
    ? "<h3 style='color:#125e58;font-size:15px;margin:22px 0 8px;'>" + title + "</h3><table style='border-collapse:collapse;width:100%;font-size:14px;'>" + list.map(row).join("") + "</table>"
    : "";
  const parts: string[] = [];
  if (licenses.length) parts.push(licenses.length + (licenses.length === 1 ? " license expiring" : " licenses expiring"));
  if (birthdays.length) parts.push(birthdays.length + (birthdays.length === 1 ? " upcoming birthday" : " upcoming birthdays"));
  const subject = "PTN alerts: " + parts.join(", ");
  const html = "<div style='font-family:Arial,sans-serif;color:#17322f;max-width:600px;'>" +
    "<h2 style='font-size:18px;margin:0 0 4px;'>PTN Team Tracker</h2><div style='color:#73847f;font-size:13px;'>" + esc(subject) + "</div>" +
    section("Licenses to renew (next " + LICENSE_ALERT_DAYS + " days)", licenses) +
    section("Birthdays (next " + BIRTHDAY_ALERT_DAYS + " days)", birthdays) +
    "<p style='color:#73847f;font-size:12px;margin-top:24px;'>Each item is sent once. Update the expiration date in the app after renewing.</p></div>";
  const sms = subject + "\n" + licenses.concat(birthdays).slice(0, 6).map((a) => "- " + a.title + ": " + whenText(a)).join("\n") +
    (alerts.length > 6 ? "\n+" + (alerts.length - 6) + " more, see email" : "");
  return { subject, html, sms };
}

async function sendEmail(subject: string, html: string) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: "Bearer " + Deno.env.get("RESEND_API_KEY"), "Content-Type": "application/json" },
    body: JSON.stringify({
      from: Deno.env.get("ALERT_EMAIL_FROM") || "PTN Team Tracker <onboarding@resend.dev>",
      to: (Deno.env.get("ALERT_EMAIL_TO") || "om@physicaltherapynow.com").split(",").map((s) => s.trim()),
      subject, html,
    }),
  });
  if (!res.ok) throw new Error("Resend: " + res.status + " " + (await res.text()));
}

async function sendSms(body: string) {
  const sid = Deno.env.get("TWILIO_ACCOUNT_SID"), token = Deno.env.get("TWILIO_AUTH_TOKEN");
  const from = Deno.env.get("TWILIO_FROM"), to = Deno.env.get("ALERT_SMS_TO");
  if (!sid || !token || !from || !to) return "skipped (Twilio not configured)";
  for (const number of to.split(",").map((s) => s.trim()).filter(Boolean)) {
    const res = await fetch("https://api.twilio.com/2010-04-01/Accounts/" + sid + "/Messages.json", {
      method: "POST",
      headers: { Authorization: "Basic " + btoa(sid + ":" + token), "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ From: from, To: number, Body: body }),
    });
    if (!res.ok) throw new Error("Twilio: " + res.status + " " + (await res.text()));
  }
  return "sent";
}

Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    return new Response("Unauthorized", { status: 401 });
  }
  try {
    const today = todayISO();
    const alerts = await dropAlreadySent(await collectAlerts(today));
    if (!alerts.length) return Response.json({ today, sent: 0 });

    const { subject, html, sms } = buildEmail(alerts);
    // Email is the primary channel: if it fails nothing is logged, so the
    // same alerts are retried on the next run.
    await sendEmail(subject, html);
    let smsResult: string;
    try { smsResult = await sendSms(sms); } catch (e) { smsResult = "failed: " + (e as Error).message; }

    await db("alert_log?on_conflict=kind,ref_id,target_date", {
      method: "POST",
      headers: { Prefer: "resolution=ignore-duplicates" },
      body: JSON.stringify(alerts.map((a) => ({ kind: a.kind, ref_id: a.refId, target_date: a.targetDate }))),
    });
    return Response.json({ today, sent: alerts.length, sms: smsResult });
  } catch (e) {
    console.error(e);
    return Response.json({ error: (e as Error).message }, { status: 500 });
  }
});
