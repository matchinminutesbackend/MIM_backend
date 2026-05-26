import { useState, useEffect, useCallback } from "react";
import { Flag, Ban, CheckCircle, Clock, XCircle, ChevronDown, Unlock } from "lucide-react";

const BASE = import.meta.env.VITE_API_URL ?? "";

function adminHeaders() {
  const token = localStorage.getItem("admin_token");
  return { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) };
}

const STATUS_STYLES = {
  pending:   "bg-yellow-50 text-yellow-700 border-yellow-200",
  reviewed:  "bg-blue-50 text-blue-700 border-blue-200",
  resolved:  "bg-green-50 text-green-700 border-green-200",
  dismissed: "bg-gray-100 text-gray-500 border-gray-200",
};

const STATUS_ICONS = {
  pending:   <Clock size={12} />,
  reviewed:  <CheckCircle size={12} />,
  resolved:  <CheckCircle size={12} />,
  dismissed: <XCircle size={12} />,
};

export default function ReportsTab() {
  const [reports, setReports]       = useState([]);
  const [loading, setLoading]       = useState(true);
  const [filterStatus, setFilter]   = useState("");
  const [expanded, setExpanded]     = useState(null);
  const [adminNote, setAdminNote]   = useState({});
  const [saving, setSaving]         = useState({});
  const [banning, setBanning]       = useState({});
  const [banReason, setBanReason]   = useState({});
  const [banDuration, setBanDuration] = useState({});

  const load = useCallback(async () => {
    setLoading(true);
    const qs = filterStatus ? `?status=${filterStatus}` : "";
    const res = await fetch(`${BASE}/admin/reports${qs}`, { headers: adminHeaders() });
    const data = await res.json();
    setReports(Array.isArray(data) ? data : []);
    setLoading(false);
  }, [filterStatus]);

  useEffect(() => { load(); }, [load]);

  async function updateStatus(id, status, note) {
    setSaving(s => ({ ...s, [id]: true }));
    await fetch(`${BASE}/admin/reports/${id}`, {
      method: "PATCH",
      headers: adminHeaders(),
      body: JSON.stringify({ status, admin_note: note || undefined }),
    });
    setSaving(s => ({ ...s, [id]: false }));
    load();
  }

  const DURATIONS = [
    { value: "1d",        label: "1 Day" },
    { value: "7d",        label: "1 Week" },
    { value: "30d",       label: "1 Month" },
    { value: "365d",      label: "1 Year" },
    { value: "permanent", label: "Permanent" },
  ];

  async function banUser(userId, reportId, reason, duration) {
    setBanning(b => ({ ...b, [reportId]: true }));
    await fetch(`${BASE}/admin/users/${userId}/ban`, {
      method: "POST",
      headers: adminHeaders(),
      body: JSON.stringify({
        reason: reason || "Violated community guidelines",
        duration: duration || "permanent",
      }),
    });
    await updateStatus(reportId, "resolved", `User banned (${duration || "permanent"}).`);
    setBanning(b => ({ ...b, [reportId]: false }));
  }

  const counts = reports.reduce((acc, r) => {
    acc[r.status] = (acc[r.status] || 0) + 1;
    return acc;
  }, {});

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900 flex items-center gap-2">
            <Flag size={20} className="text-pink-500" /> Reports & Complaints
          </h2>
          <p className="text-sm text-gray-500 mt-0.5">
            {counts.pending || 0} pending · {counts.resolved || 0} resolved
          </p>
        </div>
        <select
          value={filterStatus}
          onChange={e => setFilter(e.target.value)}
          className="text-sm border border-gray-200 rounded-xl px-3 py-2 focus:outline-none focus:ring-2 focus:ring-pink-400"
        >
          <option value="">All statuses</option>
          <option value="pending">Pending</option>
          <option value="reviewed">Reviewed</option>
          <option value="resolved">Resolved</option>
          <option value="dismissed">Dismissed</option>
        </select>
      </div>

      {/* List */}
      {loading ? (
        <div className="space-y-3">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-24 bg-gray-100 rounded-2xl animate-pulse" />
          ))}
        </div>
      ) : reports.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          <Flag size={36} className="mx-auto mb-3 opacity-30" />
          <p className="font-medium">No reports found</p>
        </div>
      ) : (
        <div className="space-y-3">
          {reports.map(r => {
            const isOpen = expanded === r.id;
            return (
              <div key={r.id} className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
                {/* Summary row */}
                <button
                  onClick={() => setExpanded(isOpen ? null : r.id)}
                  className="w-full flex items-center gap-3 p-4 text-left hover:bg-gray-50 transition"
                >
                  {/* Reporter avatar */}
                  <img
                    src={r.reporter?.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(r.reporter?.name || "?")}&background=fce7f3&color=ec4899&size=40`}
                    alt={r.reporter?.name}
                    className="w-10 h-10 rounded-full object-cover flex-shrink-0"
                  />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-sm font-semibold text-gray-800">{r.reporter?.name || "Unknown"}</span>
                      <span className="text-gray-400 text-xs">reported</span>
                      <span className="text-sm font-semibold text-gray-800">{r.reported?.name || "General complaint"}</span>
                    </div>
                    <p className="text-xs text-pink-600 font-medium mt-0.5 truncate">{r.reason}</p>
                  </div>
                  <div className="flex items-center gap-2 flex-shrink-0">
                    <span className={`inline-flex items-center gap-1 text-[11px] font-semibold px-2.5 py-1 rounded-full border ${STATUS_STYLES[r.status]}`}>
                      {STATUS_ICONS[r.status]} {r.status}
                    </span>
                    <ChevronDown size={16} className={`text-gray-400 transition-transform ${isOpen ? "rotate-180" : ""}`} />
                  </div>
                </button>

                {/* Expanded detail */}
                {isOpen && (
                  <div className="px-4 pb-4 border-t border-gray-50 space-y-4">
                    {/* Profiles side by side */}
                    <div className="flex gap-3 pt-3">
                      {[{ label: "Reporter", p: r.reporter }, { label: "Reported", p: r.reported }].map(({ label, p }) => (
                        <div key={label} className="flex-1 bg-gray-50 rounded-xl p-3">
                          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-2">{label}</p>
                          {p ? (
                            <div className="flex items-center gap-2">
                              <img src={p.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(p.name)}&background=fce7f3&color=ec4899&size=32`}
                                className="w-8 h-8 rounded-full object-cover" alt={p.name} />
                              <div>
                                <p className="text-sm font-semibold text-gray-800">{p.name}</p>
                                <p className="text-[11px] text-gray-400">{p.id?.slice(0, 8)}…</p>
                              </div>
                            </div>
                          ) : (
                            <p className="text-sm text-gray-400 italic">—</p>
                          )}
                        </div>
                      ))}
                    </div>

                    {/* Description */}
                    {r.description && (
                      <div className="bg-gray-50 rounded-xl p-3">
                        <p className="text-[11px] font-bold text-gray-400 uppercase tracking-wider mb-1">Description</p>
                        <p className="text-sm text-gray-700 leading-relaxed">{r.description}</p>
                      </div>
                    )}

                    <p className="text-[11px] text-gray-400">{new Date(r.created_at).toLocaleString()}</p>

                    {/* Admin note */}
                    <div>
                      <label className="text-xs font-semibold text-gray-600 mb-1 block">Admin note</label>
                      <textarea
                        rows={2}
                        value={adminNote[r.id] ?? r.admin_note ?? ""}
                        onChange={e => setAdminNote(n => ({ ...n, [r.id]: e.target.value }))}
                        className="w-full text-sm border border-gray-200 rounded-xl px-3 py-2 focus:outline-none focus:ring-2 focus:ring-pink-400 resize-none"
                        placeholder="Add a note…"
                      />
                    </div>

                    {/* Status actions */}
                    <div className="flex flex-wrap gap-2">
                      {["reviewed", "resolved", "dismissed"].map(s => (
                        <button
                          key={s}
                          disabled={saving[r.id] || r.status === s}
                          onClick={() => updateStatus(r.id, s, adminNote[r.id] ?? r.admin_note)}
                          className={`text-xs font-semibold px-3 py-1.5 rounded-full border transition disabled:opacity-40 ${STATUS_STYLES[s]}`}
                        >
                          {saving[r.id] ? "…" : `Mark ${s}`}
                        </button>
                      ))}
                    </div>

                    {/* Ban / Unban section */}
                    {r.reported && (
                      r.reported.is_banned ? (
                        <div className="border border-green-100 rounded-xl p-3 bg-green-50 space-y-2">
                          <p className="text-xs font-bold text-green-700 flex items-center gap-1.5">
                            <Unlock size={13} /> User is currently banned
                          </p>
                          {r.reported.ban_reason && (
                            <p className="text-xs text-green-600">Reason: {r.reported.ban_reason}</p>
                          )}
                          <button
                            disabled={banning[r.id]}
                            onClick={async () => {
                              setBanning(b => ({ ...b, [r.id]: true }));
                              await fetch(`${BASE}/admin/users/${r.reported.id}/unban`, {
                                method: "POST", headers: adminHeaders(),
                              });
                              setBanning(b => ({ ...b, [r.id]: false }));
                              load();
                            }}
                            className="w-full bg-green-600 hover:bg-green-700 text-white text-sm font-semibold py-2 rounded-lg transition disabled:opacity-50"
                          >
                            {banning[r.id] ? "Unbanning…" : `Unban ${r.reported.name}`}
                          </button>
                        </div>
                      ) : (
                        <div className="border border-red-100 rounded-xl p-3 bg-red-50 space-y-2">
                          <p className="text-xs font-bold text-red-600 flex items-center gap-1.5">
                            <Ban size={13} /> Ban User
                          </p>
                          <input
                            type="text"
                            placeholder="Ban reason (shown to user)"
                            value={banReason[r.id] || ""}
                            onChange={e => setBanReason(b => ({ ...b, [r.id]: e.target.value }))}
                            className="w-full text-sm border border-red-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-red-400 bg-white"
                          />
                          <select
                            value={banDuration[r.id] || "permanent"}
                            onChange={e => setBanDuration(b => ({ ...b, [r.id]: e.target.value }))}
                            className="w-full text-sm border border-red-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-red-400 bg-white"
                          >
                            {DURATIONS.map(d => (
                              <option key={d.value} value={d.value}>{d.label}</option>
                            ))}
                          </select>
                          <button
                            disabled={banning[r.id]}
                            onClick={() => banUser(r.reported.id, r.id, banReason[r.id], banDuration[r.id])}
                            className="w-full bg-red-500 hover:bg-red-600 text-white text-sm font-semibold py-2 rounded-lg transition disabled:opacity-50"
                          >
                            {banning[r.id] ? "Banning…" : `Ban ${r.reported.name}`}
                          </button>
                        </div>
                      )
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
