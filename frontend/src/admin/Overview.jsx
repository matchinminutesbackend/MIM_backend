import { useEffect, useState } from "react";
import {
  Users as UsersIcon,
  UserPlus,
  BadgeCheck,
  Banknote,
  Gift,
  TrendingUp,
  IndianRupee,
  AlertCircle,
} from "lucide-react";
import { adminApi } from "../api/adminClient";
import { Card, SectionHeader, formatINR } from "./ui";

/**
 * Overview — the first screen an admin lands on.
 *
 * Two bands:
 *   1. KPI cards — eight numbers that tell you at a glance if anything
 *      needs action (pending verifications, pending withdrawals).
 *   2. Signup trend — a 14-day bar chart rendered in plain SVG so we
 *      don't pull in a charting lib.
 */
export default function Overview() {
  const [stats, setStats] = useState(null);
  const [trend, setTrend] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    Promise.all([adminApi.stats(), adminApi.signupTrend(14)])
      .then(([s, t]) => {
        if (cancelled) return;
        setStats(s);
        setTrend(t);
      })
      .catch((err) => !cancelled && setError(err.message || "Could not load stats"));
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="space-y-8">
      <SectionHeader
        title="Overview"
        description="Platform health at a glance. Numbers refresh on page load — hit refresh for the latest."
      />

      {error ? (
        <Card className="p-4 text-sm text-red-300 border-red-900/50 bg-red-950/30 flex items-center gap-2">
          <AlertCircle className="w-4 h-4" />
          {error}
        </Card>
      ) : null}

      {/* KPI grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Kpi
          icon={UsersIcon}
          label="Total users"
          value={stats?.total_users}
          hint="All signups to date"
        />
        <Kpi
          icon={UserPlus}
          label="New today"
          value={stats?.signups_today}
          hint={`${stats?.signups_week ?? 0} this week`}
          accent="pink"
        />
        <Kpi
          icon={TrendingUp}
          label="Paid subscribers"
          value={stats?.paid_users}
          hint="Plus + Pro active"
          accent="green"
        />
        <Kpi
          icon={IndianRupee}
          label="Active MRR (approx)"
          value={stats ? formatINR(stats.revenue_active_inr || 0) : null}
          hint="Sum of active sub periods"
          isText
        />
        <Kpi
          icon={BadgeCheck}
          label="Pending verifications"
          value={stats?.pending_verifications}
          hint="Awaiting approval"
          accent={stats?.pending_verifications ? "amber" : "slate"}
        />
        <Kpi
          icon={Banknote}
          label="Withdrawals to process"
          value={stats?.pending_withdrawals}
          hint="User payout requests"
          accent={stats?.pending_withdrawals ? "amber" : "slate"}
        />
        <Kpi
          icon={Gift}
          label="Gift volume"
          value={stats?.gift_volume_credits}
          hint="Credits · all-time delivered"
        />
        <Kpi
          icon={TrendingUp}
          label="Signups · last 7d"
          value={stats?.signups_week}
          hint="Rolling weekly"
        />
      </div>

      {/* Trend */}
      <Card className="p-5">
        <div className="flex items-end justify-between mb-4">
          <div>
            <div className="text-xs uppercase tracking-widest text-slate-500">
              Signup trend
            </div>
            <div className="text-sm text-slate-300">Daily registrations · last 14 days</div>
          </div>
          <div className="text-xs text-slate-500">
            Total: <span className="text-slate-200">{trend.reduce((a, b) => a + b.count, 0)}</span>
          </div>
        </div>
        <TrendChart data={trend} />
      </Card>
    </div>
  );
}

function Kpi({ icon: Icon, label, value, hint, accent = "slate", isText = false }) {
  const accents = {
    slate: "text-slate-200",
    pink:  "text-pink-300",
    green: "text-emerald-300",
    amber: "text-amber-300",
  };
  return (
    <Card className="p-4">
      <div className="flex items-start justify-between">
        <div className="text-xs uppercase tracking-widest text-slate-500">{label}</div>
        <Icon className="w-4 h-4 text-slate-500" />
      </div>
      <div className={`mt-2 text-2xl font-semibold tabular-nums ${accents[accent]}`}>
        {value === null || value === undefined
          ? "—"
          : isText
          ? value
          : typeof value === "number"
          ? value.toLocaleString("en-IN")
          : value}
      </div>
      {hint ? <div className="text-[11px] text-slate-500 mt-1">{hint}</div> : null}
    </Card>
  );
}

function TrendChart({ data }) {
  if (!data || !data.length) {
    return <div className="h-40 flex items-center justify-center text-sm text-slate-500">No data yet</div>;
  }
  const max = Math.max(1, ...data.map((d) => d.count));
  return (
    <div className="flex items-end gap-1.5 h-40">
      {data.map((d) => {
        const h = Math.round((d.count / max) * 100);
        return (
          <div
            key={d.date}
            className="flex-1 flex flex-col items-center gap-1 group"
            title={`${d.date} · ${d.count}`}
          >
            <div className="text-[9px] text-slate-500 opacity-0 group-hover:opacity-100 transition-opacity">
              {d.count}
            </div>
            <div
              className="w-full rounded-t-sm bg-pink-500/60 group-hover:bg-pink-400 transition-colors"
              style={{ height: `${Math.max(2, h)}%` }}
            />
            <div className="text-[9px] text-slate-600">{d.date.slice(5)}</div>
          </div>
        );
      })}
    </div>
  );
}
