import { useEffect, useState } from "react";
import { Save, RotateCcw } from "lucide-react";
import { adminApi } from "../api/adminClient";
import {
  Card,
  SectionHeader,
  Pill,
  Button,
  TextInput,
  Empty,
  formatINR,
} from "./ui";

export default function PlansTab() {
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [drafts, setDrafts] = useState({});

  async function load() {
    setLoading(true);
    try {
      const res = await adminApi.listPlans();
      setPlans(res || []);
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

  async function savePrice(p) {
    const next = drafts[p.slug];
    if (next === undefined) return;
    try {
      await adminApi.updatePlan(p.slug, Number(next));
      load();
    } catch (e) {
      alert(e.message);
    }
  }

  async function resetPrice(p) {
    if (!window.confirm(`Reset ${p.label} to default (${formatINR(p.default_monthly_inr)}/mo)?`)) return;
    try {
      await adminApi.updatePlan(p.slug, 0);
      load();
    } catch (e) {
      alert(e.message);
    }
  }

  return (
    <div className="space-y-6">
      <SectionHeader
        title="Subscription Plans"
        description="Tune per-month pricing for Plus and Pro plans. Overrides apply immediately to new purchases; existing subscribers keep their original terms."
      />

      {err ? (
        <Card className="p-3 text-sm text-red-300 border-red-900/50 bg-red-950/30">
          {err}
        </Card>
      ) : null}

      {loading ? (
        <Card className="p-10 text-center text-sm text-slate-500">Loading plans…</Card>
      ) : !plans.length ? (
        <Card><Empty title="No plans defined" /></Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {["plus", "pro"].map((tier) => (
            <Card key={tier} className="overflow-hidden">
              <div className="px-5 py-4 border-b border-slate-800 flex items-center justify-between">
                <div>
                  <div className="text-xs uppercase tracking-widest text-slate-500">{tier === "plus" ? "Plus tier" : "Pro tier"}</div>
                  <div className="text-sm text-slate-300">
                    {tier === "plus"
                      ? "Unlimited hearts & passes"
                      : "Plus + voice & video calls"}
                  </div>
                </div>
                <Pill tone={tier === "pro" ? "pink" : "blue"}>
                  {tier.toUpperCase()}
                </Pill>
              </div>

              <div className="divide-y divide-slate-800">
                {plans
                  .filter((p) => p.tier === tier)
                  .map((p) => {
                    const draft = drafts[p.slug];
                    const current = draft ?? p.monthly_inr;
                    const dirty = draft !== undefined && Number(draft) !== p.monthly_inr;
                    return (
                      <div key={p.slug} className="px-5 py-4 flex flex-wrap items-center gap-3">
                        <div className="flex-1 min-w-[160px]">
                          <div className="text-sm font-medium text-white">{p.label}</div>
                          <div className="text-[11px] text-slate-500">
                            {p.months} month{p.months > 1 ? "s" : ""} ·
                            {" "}Total {formatINR(Number(current) * p.months)} at checkout
                          </div>
                        </div>

                        <div>
                          <div className="text-[10px] uppercase tracking-wider text-slate-500 mb-1">
                            Price / month
                          </div>
                          <div className="flex items-center gap-2">
                            <span className="text-slate-500 text-sm">₹</span>
                            <TextInput
                              type="number"
                              min={1}
                              value={current}
                              onChange={(e) =>
                                setDrafts((d) => ({ ...d, [p.slug]: e.target.value }))
                              }
                              className="w-24"
                            />
                          </div>
                        </div>

                        <div className="flex items-center gap-2">
                          {p.is_overridden ? (
                            <Pill tone="amber">Overridden</Pill>
                          ) : (
                            <Pill tone="slate">Default</Pill>
                          )}
                        </div>

                        <div className="ml-auto flex items-center gap-2">
                          {p.is_overridden ? (
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => resetPrice(p)}
                              title="Reset to default"
                            >
                              <RotateCcw className="w-3.5 h-3.5" />
                            </Button>
                          ) : null}
                          <Button
                            variant={dirty ? "primary" : "outline"}
                            size="sm"
                            disabled={!dirty}
                            onClick={() => savePrice(p)}
                          >
                            <Save className="w-3.5 h-3.5" /> Save
                          </Button>
                        </div>
                      </div>
                    );
                  })}
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
