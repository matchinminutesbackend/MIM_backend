import { useEffect, useState } from "react";
import { Save, Users, Lock, Unlock, Zap } from "lucide-react";
import { adminApi } from "../api/adminClient";
import { Card, SectionHeader, Button, TextInput, Empty } from "./ui";

function PlatformToggle({ rows, onSaved }) {
  const row = rows.find(r => r.key === "platform_open");
  const isOpen = row ? row.value !== false : true;
  const [saving, setSaving] = useState(false);

  async function toggle() {
    setSaving(true);
    try {
      await adminApi.updateSetting("platform_open", !isOpen);
      onSaved();
    } catch (e) {
      alert(e.message || "Failed to update");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card className="p-5">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-3">
          <div className={`w-10 h-10 rounded-full flex items-center justify-center ${isOpen ? "bg-green-500/15" : "bg-red-500/15"}`}>
            {isOpen
              ? <Unlock className="w-5 h-5 text-green-400" />
              : <Lock className="w-5 h-5 text-red-400" />}
          </div>
          <div>
            <div className="text-sm font-semibold text-white flex items-center gap-2">
              Platform Access
              <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${isOpen ? "bg-green-500/20 text-green-400" : "bg-red-500/20 text-red-400"}`}>
                {isOpen ? "Open" : "Locked"}
              </span>
            </div>
            <div className="text-xs text-slate-500 mt-0.5">
              {isOpen
                ? "Users can access the dashboard and explore normally."
                : "All users see a \"Profile Under Review\" screen. Nobody can access the dashboard."}
            </div>
          </div>
        </div>
        <button
          onClick={toggle}
          disabled={saving}
          className={`relative w-12 h-6 rounded-full transition-colors duration-200 focus:outline-none ${isOpen ? "bg-green-500" : "bg-slate-700"}`}
        >
          <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform duration-200 ${isOpen ? "translate-x-6" : "translate-x-0"}`} />
        </button>
      </div>
    </Card>
  );
}

function InstantMatchToggle({ rows, onSaved }) {
  const row = rows.find(r => r.key === "instant_match_enabled");
  const isOn = row ? row.value !== false : true;
  const [saving, setSaving] = useState(false);

  async function toggle() {
    setSaving(true);
    try {
      await adminApi.updateSetting("instant_match_enabled", !isOn);
      onSaved();
    } catch (e) {
      alert(e.message || "Failed to update");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card className="p-5">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-3">
          <div className={`w-10 h-10 rounded-full flex items-center justify-center ${isOn ? "bg-violet-500/15" : "bg-slate-700/50"}`}>
            <Zap className={`w-5 h-5 ${isOn ? "text-violet-400" : "text-slate-500"}`} />
          </div>
          <div>
            <div className="text-sm font-semibold text-white flex items-center gap-2">
              Instant Match
              <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${isOn ? "bg-violet-500/20 text-violet-400" : "bg-slate-700 text-slate-400"}`}>
                {isOn ? "Enabled" : "Disabled"}
              </span>
            </div>
            <div className="text-xs text-slate-500 mt-0.5">
              {isOn
                ? "Users can use ⚡ Instant Match to pair in real-time. Girls free · Boys 2/day free · Pro unlimited."
                : "The Instant Match button is hidden from all users. No queue entries can be created."}
            </div>
          </div>
        </div>
        <button
          onClick={toggle}
          disabled={saving}
          className={`relative w-12 h-6 rounded-full transition-colors duration-200 focus:outline-none ${isOn ? "bg-violet-500" : "bg-slate-700"}`}
        >
          <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform duration-200 ${isOn ? "translate-x-6" : "translate-x-0"}`} />
        </button>
      </div>
    </Card>
  );
}

export default function SettingsTab() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [drafts, setDrafts] = useState({});

  async function load() {
    setLoading(true);
    try {
      const res = await adminApi.listSettings();
      setRows(res || []);
      setDrafts({});
    } catch (e) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function save(row) {
    const draft = drafts[row.key];
    if (draft === undefined) return;
    let value = draft;
    // Try to parse JSON so numeric settings stay numeric. If it fails,
    // fall back to the raw string (the backend accepts `Any`).
    try {
      value = JSON.parse(draft);
    } catch {
      /* keep as string */
    }
    try {
      await adminApi.updateSetting(row.key, value);
      load();
    } catch (e) {
      alert(e.message);
    }
  }

  return (
    <div className="space-y-6">
      <SectionHeader
        title="Settings & Commission"
        description="Platform tunables — payout rate, commission share, withdrawal floor. Values are JSON; numbers without quotes."
      />

      <PlatformToggle rows={rows} onSaved={load} />
      <InstantMatchToggle rows={rows} onSaved={load} />

      {err ? (
        <Card className="p-3 text-sm text-red-300 border-red-900/50 bg-red-950/30">
          {err}
        </Card>
      ) : null}

      {loading ? (
        <Card className="p-10 text-center text-sm text-slate-500">Loading settings…</Card>
      ) : !rows.length ? (
        <Card>
          <Empty
            title="No settings defined"
            description="Run the 2026_admin migration to seed the defaults."
          />
        </Card>
      ) : (
        <Card>
          <div className="divide-y divide-slate-800">
            {rows.map((r) => {
              const current = drafts[r.key] ?? JSON.stringify(r.value);
              const dirty = drafts[r.key] !== undefined;
              return (
                <div key={r.key} className="px-5 py-4 flex flex-wrap items-center gap-4">
                  <div className="flex-1 min-w-[220px]">
                    <div className="text-sm font-medium text-white font-mono">{r.key}</div>
                    {r.description ? (
                      <div className="text-xs text-slate-500 mt-0.5 max-w-xl">
                        {r.description}
                      </div>
                    ) : null}
                  </div>
                  <TextInput
                    value={current}
                    onChange={(e) =>
                      setDrafts((d) => ({ ...d, [r.key]: e.target.value }))
                    }
                    className="w-52 font-mono"
                  />
                  <Button
                    variant={dirty ? "primary" : "outline"}
                    size="sm"
                    disabled={!dirty}
                    onClick={() => save(r)}
                  >
                    <Save className="w-3.5 h-3.5" /> Save
                  </Button>
                </div>
              );
            })}
          </div>
        </Card>
      )}
    </div>
  );
}
