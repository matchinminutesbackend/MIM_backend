import { useEffect, useState } from "react";
import { adminApi } from "../api/adminClient";
import { Card, SectionHeader, Empty, formatDate } from "./ui";

export default function AuditTab() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    let cancelled = false;
    adminApi
      .audit(200)
      .then((res) => !cancelled && setRows(res || []))
      .catch((e) => !cancelled && setErr(e.message))
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="space-y-6">
      <SectionHeader
        title="Audit Log"
        description="Every write action admins take lands here — approvals, rejections, price changes, credit adjustments, role grants. Read-only browsing of the console is not logged."
      />

      {err ? (
        <Card className="p-3 text-sm text-red-300 border-red-900/50 bg-red-950/30">
          {err}
        </Card>
      ) : null}

      {loading ? (
        <Card className="p-10 text-center text-sm text-slate-500">Loading audit log…</Card>
      ) : !rows.length ? (
        <Card>
          <Empty
            title="No entries yet"
            description="Admin actions will appear here as they happen."
          />
        </Card>
      ) : (
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-900/80 text-slate-400 text-xs uppercase tracking-wider">
                <tr>
                  <th className="text-left px-4 py-3 font-medium">When</th>
                  <th className="text-left px-4 py-3 font-medium">Admin</th>
                  <th className="text-left px-4 py-3 font-medium">Action</th>
                  <th className="text-left px-4 py-3 font-medium">Target</th>
                  <th className="text-left px-4 py-3 font-medium">Detail</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {rows.map((r) => (
                  <tr key={r.id} className="hover:bg-slate-900/40 align-top">
                    <td className="px-4 py-3 text-xs text-slate-400 whitespace-nowrap">
                      {formatDate(r.created_at)}
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-300">
                      <div>{r.admin?.name || "—"}</div>
                      <div className="text-slate-500">{r.admin?.email || ""}</div>
                    </td>
                    <td className="px-4 py-3">
                      <span className="text-xs font-mono text-pink-200 bg-pink-600/10 border border-pink-500/20 rounded px-1.5 py-0.5">
                        {r.action}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-300">
                      <div className="text-slate-400">{r.target_type || "—"}</div>
                      <div className="font-mono text-[11px] truncate max-w-[200px]">{r.target_id || ""}</div>
                    </td>
                    <td className="px-4 py-3 text-[11px] font-mono text-slate-400 max-w-md">
                      <pre className="whitespace-pre-wrap break-words">
                        {Object.keys(r.meta || {}).length
                          ? JSON.stringify(r.meta, null, 2)
                          : "—"}
                      </pre>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}
