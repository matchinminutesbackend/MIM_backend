// Slide-in drawer for drilling into a single user. Driven by
// GET /admin/users/{id}/detail — renders profile + photos, activity
// counters (likes / passes / matches / messages), payment funnel
// (plan visits, credits page visits, paywalls shown, attempts vs.
// successes vs. failures), wallet & gifts, and a live telemetry
// timeline of recent user_events.
//
// Opens from UsersTab when a row is clicked.

import { useEffect, useState } from "react";
import {
  X,
  User as UserIcon,
  CheckCircle2,
  AlertTriangle,
  Image as ImageIcon,
  Heart,
  Ban,
  MessageSquare,
  UserRoundSearch,
  CreditCard,
  Eye,
  BadgeAlert,
  Wallet as WalletIcon,
  Gift,
  Activity,
  RefreshCw,
  Phone,
  PhoneOff,
  Trash2,
  Crown,
  Loader2,
} from "lucide-react";
import { adminApi } from "../api/adminClient";
import {
  Card,
  Pill,
  Button,
  Empty,
  formatINR,
  formatDate,
  formatDay,
} from "./ui";

const TABS = [
  { key: "overview", label: "Overview",   icon: UserIcon },
  { key: "photos",   label: "Photos",     icon: ImageIcon },
  { key: "activity", label: "Activity",   icon: Activity },
  { key: "payments", label: "Payments",   icon: CreditCard },
  { key: "wallet",   label: "Wallet",     icon: WalletIcon },
  { key: "events",   label: "Events",     icon: Eye },
];

export default function UserDetailDrawer({ userId, onClose }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [tab, setTab] = useState("overview");

  async function load() {
    setLoading(true);
    setErr("");
    try {
      const res = await adminApi.getUserDetail(userId);
      setData(res || null);
    } catch (e) {
      setErr(e.message || "Failed to load user detail");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!userId) return;
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  useEffect(() => {
    function onKey(e) {
      if (e.key === "Escape") onClose?.();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const account  = data?.account || {};
  const profile  = account?.profile || {};
  const photos   = data?.photos || [];
  const activity = data?.activity || {};
  const payments = data?.payments || {};
  const wallet   = data?.wallet || {};
  const events   = data?.events || {};

  return (
    <div
      className="fixed inset-0 z-40 bg-black/70 flex justify-end"
      onClick={onClose}
    >
      <div
        className="w-full max-w-3xl h-full bg-slate-950 border-l border-slate-800 flex flex-col shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* ── Header ───────────────────────────────────────────── */}
        <div className="flex items-start justify-between p-5 border-b border-slate-800">
          <div className="flex items-center gap-3 min-w-0">
            {profile.main_image_url ? (
              <img
                src={profile.main_image_url}
                alt=""
                className="w-14 h-14 rounded-full object-cover border border-slate-800"
              />
            ) : (
              <div className="w-14 h-14 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center text-lg font-semibold text-slate-300">
                {(account.name || account.email || "?").slice(0, 1).toUpperCase()}
              </div>
            )}
            <div className="min-w-0">
              <div className="text-lg font-semibold text-white truncate">
                {account.name || "—"}
              </div>
              <div className="text-xs text-slate-400 truncate">{account.email}</div>
              <div className="flex flex-wrap gap-1.5 mt-1.5">
                {account.is_active ? (
                  <Pill tone="green">Active</Pill>
                ) : (
                  <Pill tone="red">Disabled</Pill>
                )}
                {account.is_admin ? <Pill tone="amber">Admin</Pill> : null}
                {profile.is_verified ? (
                  <Pill tone="blue">Verified</Pill>
                ) : profile.verification_status === "pending" ? (
                  <Pill tone="amber">Pending verify</Pill>
                ) : null}
                {profile.is_complete === false ? (
                  <Pill tone="slate">Incomplete</Pill>
                ) : null}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={load} disabled={loading}>
              <RefreshCw className={`w-3.5 h-3.5 ${loading ? "animate-spin" : ""}`} />
              Refresh
            </Button>
            <button
              onClick={onClose}
              className="text-slate-400 hover:text-white p-1"
              aria-label="Close"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* ── Tabs ─────────────────────────────────────────────── */}
        <div className="border-b border-slate-800 overflow-x-auto">
          <div className="flex items-center gap-1 px-3">
            {TABS.map((t) => {
              const Icon = t.icon;
              const active = tab === t.key;
              return (
                <button
                  key={t.key}
                  onClick={() => setTab(t.key)}
                  className={`flex items-center gap-1.5 text-xs px-3 py-2.5 border-b-2 transition-colors whitespace-nowrap ${
                    active
                      ? "border-pink-500 text-white"
                      : "border-transparent text-slate-400 hover:text-slate-200"
                  }`}
                >
                  <Icon className="w-3.5 h-3.5" />
                  {t.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* ── Body ─────────────────────────────────────────────── */}
        <div className="flex-1 overflow-y-auto p-5 space-y-5">
          {err ? (
            <Card className="p-3 text-sm text-red-300 border-red-900/50 bg-red-950/30">
              {err}
            </Card>
          ) : null}

          {loading && !data ? (
            <div className="text-sm text-slate-400 p-6 text-center">Loading…</div>
          ) : !data ? null : tab === "overview" ? (
            <OverviewSection account={account} profile={profile} />
          ) : tab === "photos" ? (
            <PhotosSection profile={profile} photos={photos} userId={account.id} onRefresh={load} />
          ) : tab === "activity" ? (
            <ActivitySection activity={activity} />
          ) : tab === "payments" ? (
            <PaymentsSection payments={payments} userId={account.id} onRefresh={load} />
          ) : tab === "wallet" ? (
            <WalletSection wallet={wallet} />
          ) : (
            <EventsSection events={events} />
          )}
        </div>
      </div>
    </div>
  );
}

/* ─── Tabs ──────────────────────────────────────────────────── */

function OverviewSection({ account, profile }) {
  const rows = [
    ["User ID",        account.id],
    ["Phone",          account.phone || "—"],
    ["Joined",         formatDate(account.created_at)],
    ["Last login",     formatDate(account.last_login_at)],
    ["Credit balance", (account.credit_balance ?? 0).toLocaleString("en-IN")],
  ];
  const profileRows = profile
    ? [
        ["Gender",        profile.gender || "—"],
        ["Age",           profile.age ?? profile.date_of_birth ?? "—"],
        ["City",          profile.city || "—"],
        ["State",         profile.state || "—"],
        ["Occupation",    profile.occupation || "—"],
        ["Profile complete", profile.is_complete ? "Yes" : "No"],
        ["Verification",  profile.verification_status || "—"],
      ]
    : null;

  return (
    <div className="space-y-5">
      <Card className="p-4">
        <div className="text-xs uppercase tracking-widest text-slate-500 mb-3">
          Account
        </div>
        <dl className="grid grid-cols-2 gap-y-2 gap-x-4 text-sm">
          {rows.map(([k, v]) => (
            <div key={k} className="flex flex-col min-w-0">
              <dt className="text-xs text-slate-500">{k}</dt>
              <dd className="text-slate-200 truncate">{v || "—"}</dd>
            </div>
          ))}
        </dl>
      </Card>

      {profile ? (
        <Card className="p-4">
          <div className="text-xs uppercase tracking-widest text-slate-500 mb-3">
            Profile
          </div>
          <dl className="grid grid-cols-2 gap-y-2 gap-x-4 text-sm">
            {profileRows.map(([k, v]) => (
              <div key={k} className="flex flex-col min-w-0">
                <dt className="text-xs text-slate-500">{k}</dt>
                <dd className="text-slate-200 truncate">{String(v ?? "—")}</dd>
              </div>
            ))}
          </dl>
          {profile.bio ? (
            <div className="mt-4">
              <div className="text-xs text-slate-500 mb-1">Bio</div>
              <div className="text-sm text-slate-300 bg-slate-900/50 border border-slate-800 rounded-lg px-3 py-2 whitespace-pre-wrap">
                {profile.bio}
              </div>
            </div>
          ) : null}
        </Card>
      ) : (
        <Empty
          title="No profile yet"
          description="User hasn't finished onboarding — profiles row is missing."
        />
      )}
    </div>
  );
}

function PhotosSection({ profile, photos, userId, onRefresh }) {
  const cover  = profile?.main_image_url;
  const selfie = profile?.selfie_url;
  const others = photos || [];

  const [deleting, setDeleting] = useState(null); // image_id being deleted
  const [confirm,  setConfirm]  = useState(null); // image object pending confirm

  async function handleDelete(img) {
    setDeleting(img.id);
    setConfirm(null);
    try {
      await adminApi.deleteUserPhoto(userId, img.id);
      onRefresh?.();
    } catch (e) {
      alert(e.message || "Failed to delete photo");
    } finally {
      setDeleting(null);
    }
  }

  if (!cover && !selfie && !others.length) {
    return (
      <Empty
        title="No photos uploaded"
        description="This user hasn't uploaded a main photo or any gallery images."
      />
    );
  }

  return (
    <div className="space-y-5">
      {/* Confirm dialog */}
      {confirm ? (
        <div className="fixed inset-0 z-50 bg-black/70 flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 rounded-xl p-5 max-w-sm w-full shadow-2xl">
            <div className="text-sm font-semibold text-white mb-1">Delete this photo?</div>
            <div className="text-xs text-slate-400 mb-4">
              This is permanent and cannot be undone. If it's the user's main photo, the next gallery image becomes main.
            </div>
            {confirm.url && (
              <img src={confirm.url} alt="" className="w-full aspect-video object-cover rounded-lg mb-4 border border-slate-700" />
            )}
            <div className="flex gap-2 justify-end">
              <Button variant="outline" size="sm" onClick={() => setConfirm(null)}>Cancel</Button>
              <Button
                size="sm"
                className="bg-red-600 hover:bg-red-500 text-white border-red-600"
                onClick={() => handleDelete(confirm)}
              >
                Delete photo
              </Button>
            </div>
          </div>
        </div>
      ) : null}

      <div className="grid grid-cols-2 gap-3">
        <PhotoTile label="Main photo" url={cover} />
        <PhotoTile
          label="Selfie (verification)"
          url={selfie}
          badge={profile?.verification_status}
        />
      </div>
      <div>
        <div className="text-xs uppercase tracking-widest text-slate-500 mb-2">
          Gallery ({others.length})
        </div>
        {others.length ? (
          <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
            {others.map((p) => (
              <div
                key={p.id}
                className="relative aspect-square rounded-lg overflow-hidden bg-slate-900 border border-slate-800 group"
              >
                {p.url ? (
                  <a href={p.url} target="_blank" rel="noreferrer" className="block w-full h-full">
                    <img src={p.url} alt="" className="w-full h-full object-cover" />
                  </a>
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-xs text-slate-500">
                    no url
                  </div>
                )}
                {/* Delete overlay */}
                <button
                  onClick={() => setConfirm(p)}
                  disabled={deleting === p.id}
                  className="absolute top-1 right-1 p-1 rounded-md bg-black/70 text-red-400 hover:bg-red-600 hover:text-white opacity-0 group-hover:opacity-100 transition-opacity"
                  title="Delete photo"
                >
                  {deleting === p.id
                    ? <Loader2 className="w-3.5 h-3.5 animate-spin" />
                    : <Trash2 className="w-3.5 h-3.5" />
                  }
                </button>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-xs text-slate-500">No gallery images.</div>
        )}
      </div>
    </div>
  );
}

function PhotoTile({ label, url, badge }) {
  return (
    <div>
      <div className="text-xs uppercase tracking-widest text-slate-500 mb-1 flex items-center justify-between">
        <span>{label}</span>
        {badge ? <Pill tone="slate">{badge}</Pill> : null}
      </div>
      {url ? (
        <a
          href={url}
          target="_blank"
          rel="noreferrer"
          className="block aspect-square rounded-lg overflow-hidden bg-slate-900 border border-slate-800"
        >
          <img src={url} alt="" className="w-full h-full object-cover" />
        </a>
      ) : (
        <div className="aspect-square rounded-lg border border-dashed border-slate-800 flex items-center justify-center text-slate-500 text-xs">
          Not uploaded
        </div>
      )}
    </div>
  );
}

function ActivitySection({ activity }) {
  const a = activity || {};
  const items = [
    { label: "Likes sent",       value: a.likes_sent,       icon: Heart,  tone: "pink" },
    { label: "Passes sent",      value: a.passes_sent,      icon: Ban,    tone: "slate" },
    { label: "Likes received",   value: a.likes_received,   icon: Heart,  tone: "pink" },
    { label: "Passes received",  value: a.passes_received,  icon: Ban,    tone: "slate" },
    { label: "Matches",          value: a.matches,          icon: CheckCircle2, tone: "green" },
    { label: "Conversations",    value: a.conversations,    icon: MessageSquare, tone: "blue" },
    { label: "Messages sent",    value: a.messages_sent,    icon: MessageSquare, tone: "blue" },
    { label: "Profile views (by user)", value: a.profile_views_by_user, icon: UserRoundSearch, tone: "amber" },
  ];

  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
      {items.map((it) => (
        <StatTile key={it.label} {...it} />
      ))}
    </div>
  );
}

const PLAN_OPTIONS = [
  { value: "pro_monthly", label: "Pro Monthly"  },
  { value: "pro_3m",      label: "Pro 3 Months" },
  { value: "pro_6m",      label: "Pro 6 Months" },
  { value: "pro_1y",      label: "Pro 1 Year"   },
];

function PaymentsSection({ payments, userId, onRefresh }) {
  const p = payments || {};
  const funnel = [
    { label: "Plans page visits",     value: p.plans_page_visits,    icon: Eye, tone: "slate" },
    { label: "Credits page visits",   value: p.credits_page_visits,  icon: Eye, tone: "slate" },
    { label: "Paywalls shown",        value: p.paywalls_shown,       icon: BadgeAlert, tone: "amber" },
    { label: "Payment attempts",      value: p.payment_attempts,     icon: CreditCard, tone: "blue" },
    { label: "Successful payments",   value: p.payment_successes,    icon: CheckCircle2, tone: "green" },
    { label: "Failed payments",       value: p.payment_failures,     icon: AlertTriangle, tone: "red" },
  ];

  const subs = p.subscriptions || [];
  const creds = p.credit_purchases || [];

  const [grantModal,  setGrantModal]  = useState(false);
  const [grantPlan,   setGrantPlan]   = useState("pro_monthly");
  const [grantMonths, setGrantMonths] = useState(1);
  const [grantReason, setGrantReason] = useState("");
  const [granting,    setGranting]    = useState(false);
  const [grantErr,    setGrantErr]    = useState("");

  async function submitGrant() {
    setGranting(true);
    setGrantErr("");
    try {
      await adminApi.grantSubscription(userId, grantPlan, grantMonths, grantReason || undefined);
      setGrantModal(false);
      onRefresh?.();
    } catch (e) {
      setGrantErr(e.message || "Failed to grant subscription");
    } finally {
      setGranting(false);
    }
  }

  return (
    <div className="space-y-5">
      {/* Grant subscription modal */}
      {grantModal ? (
        <div className="fixed inset-0 z-50 bg-black/70 flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 rounded-xl p-5 max-w-sm w-full shadow-2xl">
            <div className="flex items-center gap-2 mb-4">
              <Crown className="w-4 h-4 text-amber-400" />
              <span className="text-sm font-semibold text-white">Grant Free Pro Subscription</span>
            </div>

            <div className="space-y-3">
              <div>
                <label className="text-xs text-slate-400 block mb-1">Plan</label>
                <select
                  value={grantPlan}
                  onChange={e => setGrantPlan(e.target.value)}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-pink-500"
                >
                  {PLAN_OPTIONS.map(o => (
                    <option key={o.value} value={o.value}>{o.label}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="text-xs text-slate-400 block mb-1">Duration (months)</label>
                <input
                  type="number"
                  min={1}
                  max={24}
                  value={grantMonths}
                  onChange={e => setGrantMonths(Math.max(1, Math.min(24, Number(e.target.value))))}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-pink-500"
                />
              </div>
              <div>
                <label className="text-xs text-slate-400 block mb-1">Reason (optional)</label>
                <input
                  type="text"
                  value={grantReason}
                  onChange={e => setGrantReason(e.target.value)}
                  placeholder="e.g. Complimentary for early feedback"
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-pink-500"
                />
              </div>
              {grantErr ? (
                <div className="text-xs text-red-400 bg-red-950/30 border border-red-900/40 rounded-lg px-3 py-2">
                  {grantErr}
                </div>
              ) : null}
            </div>

            <div className="flex gap-2 justify-end mt-4">
              <Button variant="outline" size="sm" onClick={() => { setGrantModal(false); setGrantErr(""); }}>
                Cancel
              </Button>
              <Button
                size="sm"
                className="bg-amber-600 hover:bg-amber-500 text-white border-amber-600"
                onClick={submitGrant}
                disabled={granting}
              >
                {granting ? <Loader2 className="w-3.5 h-3.5 animate-spin mr-1" /> : <Crown className="w-3.5 h-3.5 mr-1" />}
                Grant
              </Button>
            </div>
          </div>
        </div>
      ) : null}

      {/* Funnel counters */}
      <div>
        <div className="flex items-center justify-between mb-2">
          <div className="text-xs uppercase tracking-widest text-slate-500">Funnel</div>
          <Button size="sm" className="bg-amber-600 hover:bg-amber-500 text-white border-amber-600" onClick={() => { setGrantErr(""); setGrantModal(true); }}>
            <Crown className="w-3.5 h-3.5 mr-1" />
            Grant Free Pro
          </Button>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {funnel.map((it) => <StatTile key={it.label} {...it} />)}
        </div>
      </div>

      {/* Lifetime */}
      <Card className="p-4 flex flex-wrap gap-6 items-center">
        <div>
          <div className="text-xs text-slate-500">Lifetime spend</div>
          <div className="text-xl font-semibold text-white">
            {formatINR(p.lifetime_spend_inr || 0)}
          </div>
        </div>
        <div>
          <div className="text-xs text-slate-500">Subscriptions</div>
          <div className="text-sm text-slate-200">
            {formatINR(p.lifetime_sub_inr || 0)}
          </div>
        </div>
        <div>
          <div className="text-xs text-slate-500">Credit purchases</div>
          <div className="text-sm text-slate-200">
            {formatINR(p.lifetime_credit_inr || 0)}
          </div>
        </div>
      </Card>

      {/* Subscription rows */}
      <Card className="overflow-hidden">
        <div className="px-4 py-2 text-xs uppercase tracking-widest text-slate-500 border-b border-slate-800">
          Subscription history ({subs.length})
        </div>
        {subs.length ? (
          <table className="w-full text-sm">
            <thead className="text-slate-500 text-xs">
              <tr>
                <th className="text-left px-4 py-2 font-medium">Plan</th>
                <th className="text-left px-4 py-2 font-medium">Status</th>
                <th className="text-left px-4 py-2 font-medium">Amount</th>
                <th className="text-left px-4 py-2 font-medium">Started</th>
                <th className="text-left px-4 py-2 font-medium">Renews</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {subs.map((s) => (
                <tr key={s.id}>
                  <td className="px-4 py-2">
                    <Pill tone={s.tier === "pro" ? "pink" : "blue"}>
                      {(s.tier || "").toUpperCase()} · {(s.plan || "").replace(/_/g, " ")}
                    </Pill>
                  </td>
                  <td className="px-4 py-2 text-slate-300">{s.status}</td>
                  <td className="px-4 py-2 tabular-nums">
                    {formatINR(Math.round((s.inr_paise || 0) / 100))}
                  </td>
                  <td className="px-4 py-2 text-xs text-slate-400">{formatDate(s.started_at || s.created_at)}</td>
                  <td className="px-4 py-2 text-xs text-slate-400">{formatDate(s.current_period_end)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <Empty title="No subscriptions" />
        )}
      </Card>

      {/* Credit purchases */}
      <Card className="overflow-hidden">
        <div className="px-4 py-2 text-xs uppercase tracking-widest text-slate-500 border-b border-slate-800">
          Credit purchases ({creds.length})
        </div>
        {creds.length ? (
          <table className="w-full text-sm">
            <thead className="text-slate-500 text-xs">
              <tr>
                <th className="text-left px-4 py-2 font-medium">Credits</th>
                <th className="text-left px-4 py-2 font-medium">Amount</th>
                <th className="text-left px-4 py-2 font-medium">When</th>
                <th className="text-left px-4 py-2 font-medium">Note</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {creds.map((c) => (
                <tr key={c.id}>
                  <td className="px-4 py-2 tabular-nums">{c.delta}</td>
                  <td className="px-4 py-2 tabular-nums">
                    {formatINR(Math.round(((c.meta && c.meta.inr_paise) || 0) / 100))}
                  </td>
                  <td className="px-4 py-2 text-xs text-slate-400">{formatDate(c.created_at)}</td>
                  <td className="px-4 py-2 text-xs text-slate-500 truncate max-w-xs">{c.note || "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <Empty title="No credit purchases" />
        )}
      </Card>
    </div>
  );
}

function WalletSection({ wallet }) {
  const w = wallet?.wallet || null;
  const txns = wallet?.transactions || [];
  const wds = wallet?.withdrawals || [];

  return (
    <div className="space-y-5">
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <StatTile
          label="Wallet balance (₹)"
          value={w ? Math.round((w.balance_paise || 0) / 100) : 0}
          icon={WalletIcon}
          tone="green"
        />
        <StatTile
          label="Gifts sent"
          value={wallet?.gifts_sent || 0}
          icon={Gift}
          tone="pink"
        />
        <StatTile
          label="Gifts received"
          value={wallet?.gifts_received || 0}
          icon={Gift}
          tone="amber"
        />
        <StatTile
          label="Withdrawals"
          value={wds.length}
          icon={CreditCard}
          tone="slate"
        />
      </div>

      <Card className="overflow-hidden">
        <div className="px-4 py-2 text-xs uppercase tracking-widest text-slate-500 border-b border-slate-800">
          Recent transactions ({txns.length})
        </div>
        {txns.length ? (
          <table className="w-full text-sm">
            <thead className="text-slate-500 text-xs">
              <tr>
                <th className="text-left px-4 py-2 font-medium">Kind</th>
                <th className="text-left px-4 py-2 font-medium">Delta</th>
                <th className="text-left px-4 py-2 font-medium">Note</th>
                <th className="text-left px-4 py-2 font-medium">When</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {txns.map((t) => (
                <tr key={t.id}>
                  <td className="px-4 py-2">
                    <Pill tone={t.delta > 0 ? "green" : "red"}>{t.kind}</Pill>
                  </td>
                  <td className={`px-4 py-2 tabular-nums ${t.delta > 0 ? "text-emerald-300" : "text-red-300"}`}>
                    {t.delta > 0 ? `+${t.delta}` : t.delta}
                  </td>
                  <td className="px-4 py-2 text-xs text-slate-400 truncate max-w-xs">{t.note || "—"}</td>
                  <td className="px-4 py-2 text-xs text-slate-500">{formatDate(t.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <Empty title="No wallet activity" />
        )}
      </Card>

      <Card className="overflow-hidden">
        <div className="px-4 py-2 text-xs uppercase tracking-widest text-slate-500 border-b border-slate-800">
          Withdrawal requests ({wds.length})
        </div>
        {wds.length ? (
          <table className="w-full text-sm">
            <thead className="text-slate-500 text-xs">
              <tr>
                <th className="text-left px-4 py-2 font-medium">Amount</th>
                <th className="text-left px-4 py-2 font-medium">Status</th>
                <th className="text-left px-4 py-2 font-medium">Requested</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {wds.map((w) => (
                <tr key={w.id}>
                  <td className="px-4 py-2 tabular-nums">
                    {formatINR(Math.round((w.amount_paise || 0) / 100))}
                  </td>
                  <td className="px-4 py-2">
                    <Pill
                      tone={
                        w.status === "paid"
                          ? "green"
                          : w.status === "rejected"
                          ? "red"
                          : w.status === "processing"
                          ? "amber"
                          : "slate"
                      }
                    >
                      {w.status}
                    </Pill>
                  </td>
                  <td className="px-4 py-2 text-xs text-slate-500">{formatDate(w.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <Empty title="No withdrawal requests" />
        )}
      </Card>
    </div>
  );
}

function EventsSection({ events }) {
  const totals  = events?.totals || {};
  const last7   = events?.last_7d || {};
  const recent  = events?.recent || [];

  const keys = Array.from(
    new Set([...Object.keys(totals), ...Object.keys(last7)])
  ).sort();

  return (
    <div className="space-y-5">
      <Card className="overflow-hidden">
        <div className="px-4 py-2 text-xs uppercase tracking-widest text-slate-500 border-b border-slate-800">
          Event counts
        </div>
        {keys.length ? (
          <table className="w-full text-sm">
            <thead className="text-slate-500 text-xs">
              <tr>
                <th className="text-left px-4 py-2 font-medium">Event</th>
                <th className="text-right px-4 py-2 font-medium">Last 7 days</th>
                <th className="text-right px-4 py-2 font-medium">All time</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {keys.map((k) => (
                <tr key={k}>
                  <td className="px-4 py-2 text-slate-300 font-mono text-xs">{k}</td>
                  <td className="px-4 py-2 text-right tabular-nums text-slate-200">
                    {(last7[k] || 0).toLocaleString("en-IN")}
                  </td>
                  <td className="px-4 py-2 text-right tabular-nums text-slate-200">
                    {(totals[k] || 0).toLocaleString("en-IN")}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <Empty
            title="No events tracked yet"
            description="Once the telemetry migration runs, this tab will fill up as the user browses plans, hits paywalls, pays, etc."
          />
        )}
      </Card>

      <Card className="overflow-hidden">
        <div className="px-4 py-2 text-xs uppercase tracking-widest text-slate-500 border-b border-slate-800">
          Recent activity ({recent.length})
        </div>
        {recent.length ? (
          <ul className="divide-y divide-slate-800">
            {recent.map((ev) => (
              <li key={ev.id} className="px-4 py-2.5 text-sm flex items-start gap-3">
                <EventIcon name={ev.event} />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="font-mono text-xs text-slate-200 truncate">
                      {ev.event}
                    </span>
                    {ev.target_id ? (
                      <span className="text-[11px] text-slate-500 truncate">
                        → {String(ev.target_id).slice(0, 8)}…
                      </span>
                    ) : null}
                  </div>
                  {ev.meta && Object.keys(ev.meta).length ? (
                    <div className="text-[11px] text-slate-500 truncate">
                      {JSON.stringify(ev.meta)}
                    </div>
                  ) : null}
                </div>
                <div className="text-[11px] text-slate-500 whitespace-nowrap">
                  {formatDate(ev.created_at)}
                </div>
              </li>
            ))}
          </ul>
        ) : (
          <Empty title="No recent activity" />
        )}
      </Card>
    </div>
  );
}

/* ─── Shared bits ───────────────────────────────────────────── */

function StatTile({ label, value, icon: Icon, tone = "slate" }) {
  const tones = {
    pink:  "text-pink-300",
    green: "text-emerald-300",
    red:   "text-red-300",
    blue:  "text-sky-300",
    amber: "text-amber-300",
    slate: "text-slate-300",
  };
  return (
    <Card className="p-3">
      <div className="flex items-center gap-2 text-slate-500">
        {Icon ? <Icon className={`w-3.5 h-3.5 ${tones[tone] || tones.slate}`} /> : null}
        <span className="text-[11px] uppercase tracking-wider">{label}</span>
      </div>
      <div className="text-xl font-semibold text-white mt-1 tabular-nums">
        {(value ?? 0).toLocaleString("en-IN")}
      </div>
    </Card>
  );
}

function EventIcon({ name }) {
  const map = {
    paywall_shown:    { icon: BadgeAlert, tone: "text-amber-300" },
    plans_viewed:     { icon: Eye,        tone: "text-slate-300" },
    credits_viewed:   { icon: Eye,        tone: "text-slate-300" },
    payment_started:  { icon: CreditCard, tone: "text-sky-300" },
    payment_success:  { icon: CheckCircle2, tone: "text-emerald-300" },
    payment_failed:   { icon: AlertTriangle, tone: "text-red-300" },
    profile_viewed:   { icon: UserRoundSearch, tone: "text-amber-300" },
    profile_liked:    { icon: Heart,      tone: "text-pink-300" },
    profile_passed:   { icon: Ban,        tone: "text-slate-300" },
    message_sent:     { icon: MessageSquare, tone: "text-sky-300" },
    call_started:     { icon: Phone,      tone: "text-emerald-300" },
    call_blocked:     { icon: PhoneOff,   tone: "text-red-300" },
    gift_sent:        { icon: Gift,       tone: "text-pink-300" },
  };
  const entry = map[name] || { icon: Activity, tone: "text-slate-400" };
  const Icon = entry.icon;
  return <Icon className={`w-4 h-4 mt-0.5 ${entry.tone}`} />;
}
