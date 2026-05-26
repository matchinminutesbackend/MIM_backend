import { useCallback, useEffect, useState } from "react";
import { CheckCircle2, XCircle, Loader2, X, Clock } from "lucide-react";
import { adminApi } from "../api/adminClient";
import {
  Card,
  SectionHeader,
  Pill,
  Button,
  TextInput,
  Select,
  Empty,
  formatDate,
  formatINR,
} from "./ui";

const STATUS_TONE = {
  pending:    "amber",
  processing: "blue",
  paid:       "green",
  rejected:   "red",
  cancelled:  "slate",
};

export default function WithdrawalsTab() {
  const [status, setStatus] = useState("pending");
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [actionFor, setActionFor] = useState(null); // {row, action: 'processing'|'paid'|'rejected'}

  const load = useCallback(async () => {
    setLoading(true);
    setErr("");
    try {
      const res = await adminApi.listWithdrawals({ status: status === "all" ? "" : status, limit: 100 });
      setRows(res || []);
    } catch (e) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }, [status]);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <div className="space-y-6">
      <SectionHeader
        title="Withdrawals"
        description="User payout requests. Mark each one through processing → paid once Razorpay X confirms the transfer, or reject to return the held credits."
        actions={
          <Select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="pending">Pending</option>
            <option value="processing">Processing</option>
            <option value="paid">Paid</option>
            <option value="rejected">Rejected</option>
            <option value="cancelled">Cancelled</option>
            <option value="all">All</option>
          </Select>
        }
      />

      {err ? (
        <Card className="p-3 text-sm text-red-300 border-red-900/50 bg-red-950/30">
          {err}
        </Card>
      ) : null}

      {loading ? (
        <Card className="p-10 text-center text-sm text-slate-500">
          Loading withdrawals…
        </Card>
      ) : !rows.length ? (
        <Card>
          <Empty
            title="No withdrawals"
            description="No requests in this queue right now."
          />
        </Card>
      ) : (
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-900/80 text-slate-400 text-xs uppercase tracking-wider">
                <tr>
                  <th className="text-left px-4 py-3 font-medium">User</th>
                  <th className="text-left px-4 py-3 font-medium">Amount</th>
                  <th className="text-left px-4 py-3 font-medium">Payout method</th>
                  <th className="text-left px-4 py-3 font-medium">Status</th>
                  <th className="text-left px-4 py-3 font-medium">Requested</th>
                  <th className="text-right px-4 py-3 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {rows.map((r) => (
                  <WithdrawalRow
                    key={r.id}
                    row={r}
                    onAction={(action) => setActionFor({ row: r, action })}
                  />
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {actionFor ? (
        <ActionDialog
          row={actionFor.row}
          action={actionFor.action}
          onClose={() => setActionFor(null)}
          onDone={() => {
            setActionFor(null);
            load();
          }}
        />
      ) : null}
    </div>
  );
}

function WithdrawalRow({ row, onAction }) {
  const p = row.payout;
  const payoutLine = p
    ? p.method === "upi"
      ? `UPI · ${p.upi_id || "—"}`
      : `Bank · ${p.account_name || "—"} · ${(p.account_number || "").slice(-4).padStart(4, "•")} · ${p.ifsc || ""}`
    : "Not configured";

  const canAct = row.status === "pending" || row.status === "processing";

  return (
    <tr className="hover:bg-slate-900/40">
      <td className="px-4 py-3">
        <div className="text-sm font-medium text-white">
          {row.user?.name || "—"}
        </div>
        <div className="text-xs text-slate-500">{row.user?.email || ""}</div>
      </td>
      <td className="px-4 py-3">
        <div className="text-sm text-white tabular-nums">
          {row.credits.toLocaleString("en-IN")} credits
        </div>
        <div className="text-xs text-slate-500">{formatINR(row.inr_paise, { fromPaise: true })}</div>
      </td>
      <td className="px-4 py-3 text-xs text-slate-300 max-w-[260px] truncate">
        {payoutLine}
        {row.rzp_payout_id ? (
          <div className="text-[10px] text-slate-500 mt-0.5 truncate">
            RZP: {row.rzp_payout_id}
          </div>
        ) : null}
      </td>
      <td className="px-4 py-3">
        <Pill tone={STATUS_TONE[row.status] || "slate"}>
          {row.status === "processing" ? <Loader2 className="w-3 h-3 animate-spin" /> : null}
          {row.status === "pending"    ? <Clock className="w-3 h-3" /> : null}
          {row.status === "paid"       ? <CheckCircle2 className="w-3 h-3" /> : null}
          {row.status === "rejected"   ? <XCircle className="w-3 h-3" /> : null}
          {row.status}
        </Pill>
      </td>
      <td className="px-4 py-3 text-xs text-slate-400">{formatDate(row.created_at)}</td>
      <td className="px-4 py-3 text-right">
        <div className="inline-flex items-center gap-1.5">
          {canAct ? (
            <>
              {row.status === "pending" ? (
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => onAction("processing")}
                >
                  Mark processing
                </Button>
              ) : null}
              <Button
                variant="success"
                size="sm"
                onClick={() => onAction("paid")}
              >
                Mark paid
              </Button>
              <Button
                variant="danger"
                size="sm"
                onClick={() => onAction("rejected")}
              >
                Reject
              </Button>
            </>
          ) : (
            <span className="text-xs text-slate-500">
              {row.status === "rejected" && row.failure_reason
                ? row.failure_reason
                : "—"}
            </span>
          )}
        </div>
      </td>
    </tr>
  );
}

function ActionDialog({ row, action, onClose, onDone }) {
  const [rzpId, setRzpId] = useState(row.rzp_payout_id || "");
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  const title =
    action === "paid"
      ? "Confirm payout"
      : action === "rejected"
      ? "Reject withdrawal"
      : "Mark as processing";
  const needReason = action === "rejected";
  const needRzp = action === "paid" || action === "processing";

  async function submit(e) {
    e.preventDefault();
    if (needReason && !reason.trim()) {
      setErr("Reason is required for rejections — it's shown to the user.");
      return;
    }
    setBusy(true);
    try {
      await adminApi.markWithdrawal(row.id, {
        status: action,
        rzpPayoutId: needRzp ? rzpId.trim() || null : null,
        reason: needReason ? reason.trim() : null,
      });
      onDone?.();
    } catch (e2) {
      setErr(e2.message || "Action failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/70 p-4" onClick={onClose}>
      <Card className="w-full max-w-md bg-slate-950 p-6" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between mb-4">
          <div>
            <div className="text-xs uppercase tracking-widest text-slate-500">{title}</div>
            <div className="text-base font-semibold">
              {row.user?.name || "—"} · {formatINR(row.inr_paise, { fromPaise: true })}
            </div>
            <div className="text-xs text-slate-500">{row.credits.toLocaleString("en-IN")} credits</div>
          </div>
          <button onClick={onClose} className="text-slate-400 hover:text-white">
            <X className="w-4 h-4" />
          </button>
        </div>

        <form onSubmit={submit} className="space-y-3">
          {needRzp ? (
            <label className="block">
              <span className="text-xs text-slate-400">
                Razorpay X payout ID <span className="text-slate-600">(optional)</span>
              </span>
              <TextInput
                value={rzpId}
                onChange={(e) => setRzpId(e.target.value)}
                placeholder="pout_XXXXXXXXXXX"
                className="w-full mt-1"
              />
            </label>
          ) : null}
          {needReason ? (
            <label className="block">
              <span className="text-xs text-slate-400">Reason (shown to user)</span>
              <textarea
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                rows={3}
                placeholder="Payout details invalid — please update UPI ID and try again."
                className="w-full mt-1 rounded-lg bg-slate-950 border border-slate-800 focus:border-pink-500 focus:ring-1 focus:ring-pink-500/40 outline-none text-sm px-3 py-2 placeholder-slate-600 text-slate-100"
              />
            </label>
          ) : null}

          {err ? (
            <div className="text-xs text-red-300 bg-red-950/40 border border-red-900/50 rounded-md px-3 py-2">
              {err}
            </div>
          ) : null}

          <div className="flex items-center justify-end gap-2 pt-2">
            <Button variant="outline" type="button" onClick={onClose} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant={action === "rejected" ? "danger" : "success"}
              type="submit"
              disabled={busy}
            >
              {busy ? "Working…" : `Confirm ${action}`}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
