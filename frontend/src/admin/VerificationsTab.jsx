import { useCallback, useEffect, useState } from "react";
import { Check, X, Clock, ShieldCheck, ShieldX, ImageOff } from "lucide-react";
import { adminApi } from "../api/adminClient";
import {
  Card,
  SectionHeader,
  Pill,
  Button,
  Select,
  Empty,
  formatDate,
} from "./ui";

/**
 * VerificationsTab — face-verification review queue.
 *
 * Each card shows the profile main image next to the uploaded selfie so
 * the admin can compare them in one glance. Approve flips is_verified=true
 * (and fires the signup bonus); reject requires a reason that's sent to
 * the user as `verification_note` so they know what to fix.
 */
export default function VerificationsTab() {
  const [status, setStatus] = useState("pending");
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [rejectFor, setRejectFor] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setErr("");
    try {
      const res = await adminApi.listVerifications({ status, limit: 100 });
      setRows(res || []);
    } catch (e) {
      setErr(e.message || "Failed to load verifications");
    } finally {
      setLoading(false);
    }
  }, [status]);

  useEffect(() => {
    load();
  }, [load]);

  async function approve(userId) {
    if (!window.confirm("Approve this user's verification?")) return;
    try {
      await adminApi.approveVerification(userId);
      load();
    } catch (e) {
      alert(e.message || "Approval failed");
    }
  }

  return (
    <div className="space-y-6">
      <SectionHeader
        title="Face Verifications"
        description="Review selfies submitted by users and approve or reject them. Approvals unlock the signup bonus and the verified badge."
        actions={
          <Select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
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
          Loading verifications…
        </Card>
      ) : rows.length === 0 ? (
        <Card>
          <Empty
            title={status === "pending" ? "Queue is empty" : "No entries"}
            description={
              status === "pending"
                ? "All caught up — no verifications waiting for review."
                : "Try a different status filter."
            }
          />
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {rows.map((r) => (
            <VerificationCard
              key={r.id}
              row={r}
              onApprove={() => approve(r.id)}
              onReject={() => setRejectFor(r)}
            />
          ))}
        </div>
      )}

      {rejectFor ? (
        <RejectDialog
          row={rejectFor}
          onClose={() => setRejectFor(null)}
          onDone={() => {
            setRejectFor(null);
            load();
          }}
        />
      ) : null}
    </div>
  );
}

function StatusPill({ status }) {
  if (status === "approved") return <Pill tone="green"><Check className="w-3 h-3" /> Approved</Pill>;
  if (status === "rejected") return <Pill tone="red"><X className="w-3 h-3" /> Rejected</Pill>;
  if (status === "pending") return <Pill tone="amber"><Clock className="w-3 h-3" /> Pending</Pill>;
  return <Pill tone="slate">—</Pill>;
}

function VerificationCard({ row, onApprove, onReject }) {
  const profileImg = row.main_image_url;
  const selfieImg = row.verification_image_url;

  return (
    <Card className="overflow-hidden">
      <div className="p-4 border-b border-slate-800">
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0">
            <div className="text-sm font-semibold text-white truncate">
              {row.name}
              {row.age ? (
                <span className="text-slate-500 font-normal">, {row.age}</span>
              ) : null}
            </div>
            <div className="text-xs text-slate-500 truncate">
              {row.email || "—"} · {row.city || "—"}
            </div>
          </div>
          <StatusPill status={row.verification_status} />
        </div>
        <div className="mt-1 text-[11px] text-slate-500">
          Submitted {formatDate(row.verification_submitted_at)}
        </div>
      </div>

      {/* Side-by-side comparison */}
      <div className="grid grid-cols-2 gap-px bg-slate-800">
        <ImagePane label="Profile photo" src={profileImg} />
        <ImagePane label="Selfie" src={selfieImg} highlight />
      </div>

      {/* Notes (rejection reasons show here) */}
      {row.verification_note ? (
        <div className="px-4 py-3 border-t border-slate-800 text-xs text-slate-300 bg-slate-900/40">
          <span className="text-slate-500">Note:</span> {row.verification_note}
        </div>
      ) : null}

      {/* Actions */}
      {row.verification_status === "pending" ? (
        <div className="p-4 border-t border-slate-800 flex items-center justify-end gap-2">
          <Button variant="danger" size="sm" onClick={onReject}>
            <ShieldX className="w-3.5 h-3.5" /> Reject
          </Button>
          <Button variant="success" size="sm" onClick={onApprove}>
            <ShieldCheck className="w-3.5 h-3.5" /> Approve
          </Button>
        </div>
      ) : null}
    </Card>
  );
}

function ImagePane({ label, src, highlight }) {
  return (
    <div className={`aspect-square bg-slate-950 relative ${highlight ? "ring-1 ring-inset ring-pink-500/40" : ""}`}>
      {src ? (
        <img src={src} alt={label} className="w-full h-full object-cover" />
      ) : (
        <div className="w-full h-full flex flex-col items-center justify-center text-slate-600 text-xs gap-2">
          <ImageOff className="w-5 h-5" />
          No {label.toLowerCase()}
        </div>
      )}
      <div className="absolute bottom-1.5 left-1.5 text-[10px] uppercase tracking-widest bg-black/60 text-white px-1.5 py-0.5 rounded">
        {label}
      </div>
    </div>
  );
}

// Canned rejection reasons — phrased as direct, user-facing messages so
// the selected value can be sent to the user as-is via `verification_note`.
// Keep wording polite and actionable ("please do X") since the user reads
// it verbatim on their dashboard. The "other" sentinel flips the dialog to
// a free-text textarea for anything not listed here.
const REJECT_REASONS = [
  { value: "blurry",          label: "Selfie is blurry — please upload a clearer photo in good light." },
  { value: "too_dark",        label: "Photo is too dark — please retake in a well-lit area." },
  { value: "face_not_visible",label: "Your face isn't clearly visible — please center your face in the oval." },
  { value: "face_covered",    label: "Face is partially covered (mask, sunglasses, hand) — please remove and retake." },
  { value: "multiple_faces",  label: "Multiple people in the photo — please take the selfie alone." },
  { value: "no_face",         label: "No face detected in the photo — please retake with your face in frame." },
  { value: "mismatch",        label: "Selfie doesn't match your profile photos — please upload a selfie of the account owner." },
  { value: "not_selfie",      label: "This doesn't look like a live selfie — please take a new photo with your camera (no screenshots, no photo of a photo)." },
  { value: "heavily_filtered",label: "Photo appears heavily filtered or edited — please upload an unedited selfie." },
  { value: "ai_generated",    label: "Photo appears AI-generated — please upload a real selfie." },
  { value: "fake_profile",    label: "Profile photos appear to be not of you — please upload real photos of yourself." },
  { value: "inappropriate",   label: "Photo contains inappropriate or explicit content — please upload a clean selfie." },
  { value: "underage",        label: "You appear to be under 18. MatchInMinutes is only for adults 18+." },
  { value: "low_resolution",  label: "Photo resolution is too low — please upload a higher-quality selfie." },
  { value: "eyes_closed",     label: "Eyes are closed or looking away — please look at the camera and retake." },
  { value: "wrong_angle",     label: "Photo angle makes your face hard to verify — please face the camera straight on." },
  { value: "other",           label: "Other (type a custom reason)" },
];

function RejectDialog({ row, onClose, onDone }) {
  const [preset, setPreset] = useState("");
  const [customReason, setCustomReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  const isOther = preset === "other";
  const finalReason = isOther
    ? customReason.trim()
    : (REJECT_REASONS.find((r) => r.value === preset)?.label || "");

  async function submit(e) {
    e.preventDefault();
    if (!preset) {
      setErr("Pick a reason — it's shown to the user so they know what to fix.");
      return;
    }
    if (isOther && !customReason.trim()) {
      setErr("Type a custom reason for this user.");
      return;
    }
    setBusy(true);
    try {
      await adminApi.rejectVerification(row.id, finalReason);
      onDone?.();
    } catch (e2) {
      setErr(e2.message || "Rejection failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/70 p-4" onClick={onClose}>
      <Card className="w-full max-w-md bg-slate-950 p-6" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between mb-4">
          <div>
            <div className="text-xs uppercase tracking-widest text-slate-500">
              Reject verification
            </div>
            <div className="text-base font-semibold">{row.name}</div>
          </div>
          <button onClick={onClose} className="text-slate-400 hover:text-white">
            <X className="w-4 h-4" />
          </button>
        </div>

        <form onSubmit={submit} className="space-y-3">
          <label className="block">
            <span className="text-xs text-slate-400">Reason (shown to the user)</span>
            <select
              value={preset}
              onChange={(e) => { setPreset(e.target.value); setErr(""); }}
              className="w-full mt-1 rounded-lg bg-slate-950 border border-slate-800 focus:border-pink-500 focus:ring-1 focus:ring-pink-500/40 outline-none text-sm px-3 py-2 text-slate-100"
            >
              <option value="">Select a reason…</option>
              {REJECT_REASONS.map((r) => (
                <option key={r.value} value={r.value}>{r.label}</option>
              ))}
            </select>
          </label>

          {isOther ? (
            <label className="block">
              <span className="text-xs text-slate-400">Custom reason</span>
              <textarea
                value={customReason}
                onChange={(e) => setCustomReason(e.target.value)}
                rows={3}
                autoFocus
                placeholder="Describe what the user needs to fix…"
                className="w-full mt-1 rounded-lg bg-slate-950 border border-slate-800 focus:border-pink-500 focus:ring-1 focus:ring-pink-500/40 outline-none text-sm px-3 py-2 placeholder-slate-600 text-slate-100"
              />
            </label>
          ) : preset ? (
            <div className="text-[11px] text-slate-500 bg-slate-900/50 border border-slate-800 rounded-md px-3 py-2 leading-relaxed">
              <span className="uppercase tracking-widest text-[10px] text-slate-600">Preview</span>
              <div className="mt-1 text-slate-300">{finalReason}</div>
            </div>
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
            <Button variant="danger" type="submit" disabled={busy}>
              {busy ? "Rejecting…" : "Reject with reason"}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
