import { useEffect, useState } from "react";
import { Save, Power, PowerOff } from "lucide-react";
import { adminApi } from "../api/adminClient";
import {
  Card,
  SectionHeader,
  Pill,
  Button,
  TextInput,
  Select,
  Empty,
} from "./ui";

const TIERS = [
  { value: "common",    label: "Common",    tone: "slate" },
  { value: "rare",      label: "Rare",      tone: "blue" },
  { value: "epic",      label: "Epic",      tone: "pink" },
  { value: "legendary", label: "Legendary", tone: "amber" },
];

export default function GiftsTab() {
  const [gifts, setGifts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [drafts, setDrafts] = useState({}); // id → partial patch

  async function load() {
    setLoading(true);
    try {
      const res = await adminApi.listGifts();
      setGifts(res || []);
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

  function draft(id, patch) {
    setDrafts((d) => ({ ...d, [id]: { ...(d[id] || {}), ...patch } }));
  }

  async function save(g) {
    const patch = drafts[g.id];
    if (!patch) return;
    try {
      await adminApi.updateGift(g.id, patch);
      load();
    } catch (e) {
      alert(e.message);
    }
  }

  async function toggleActive(g) {
    try {
      await adminApi.updateGift(g.id, { is_active: !g.is_active });
      load();
    } catch (e) {
      alert(e.message);
    }
  }

  return (
    <div className="space-y-6">
      <SectionHeader
        title="Gift Catalog"
        description="Adjust prices, rename items, or retire gifts. Changes take effect immediately across the app. Minimum cost is 30 credits."
      />

      {err ? (
        <Card className="p-3 text-sm text-red-300 border-red-900/50 bg-red-950/30">
          {err}
        </Card>
      ) : null}

      {loading ? (
        <Card className="p-10 text-center text-sm text-slate-500">Loading gifts…</Card>
      ) : !gifts.length ? (
        <Card><Empty title="No gifts in catalog" /></Card>
      ) : (
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-900/80 text-slate-400 text-xs uppercase tracking-wider">
                <tr>
                  <th className="text-left px-4 py-3 font-medium">Gift</th>
                  <th className="text-left px-4 py-3 font-medium">Tier</th>
                  <th className="text-left px-4 py-3 font-medium">Cost (credits)</th>
                  <th className="text-left px-4 py-3 font-medium">Order</th>
                  <th className="text-left px-4 py-3 font-medium">Status</th>
                  <th className="text-right px-4 py-3 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {gifts.map((g) => {
                  const d = drafts[g.id] || {};
                  const dirty = Object.keys(d).length > 0;
                  const tier = d.tier ?? g.tier;
                  return (
                    <tr key={g.id} className="hover:bg-slate-900/40">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div className="text-2xl leading-none">{d.icon ?? g.icon}</div>
                          <TextInput
                            value={d.name ?? g.name}
                            onChange={(e) => draft(g.id, { name: e.target.value })}
                            className="w-40"
                          />
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <Select
                          value={tier}
                          onChange={(e) => draft(g.id, { tier: e.target.value })}
                        >
                          {TIERS.map((t) => (
                            <option key={t.value} value={t.value}>{t.label}</option>
                          ))}
                        </Select>
                      </td>
                      <td className="px-4 py-3">
                        <TextInput
                          type="number"
                          min={30}
                          value={d.cost ?? g.cost}
                          onChange={(e) =>
                            draft(g.id, { cost: Number(e.target.value) })
                          }
                          className="w-24"
                        />
                      </td>
                      <td className="px-4 py-3">
                        <TextInput
                          type="number"
                          value={d.sort_order ?? g.sort_order}
                          onChange={(e) =>
                            draft(g.id, { sort_order: Number(e.target.value) })
                          }
                          className="w-16"
                        />
                      </td>
                      <td className="px-4 py-3">
                        {g.is_active ? (
                          <Pill tone="green">Active</Pill>
                        ) : (
                          <Pill tone="slate">Retired</Pill>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <div className="inline-flex items-center gap-2">
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => toggleActive(g)}
                            title={g.is_active ? "Retire" : "Reactivate"}
                          >
                            {g.is_active ? (
                              <PowerOff className="w-3.5 h-3.5 text-red-300" />
                            ) : (
                              <Power className="w-3.5 h-3.5 text-emerald-300" />
                            )}
                          </Button>
                          <Button
                            variant={dirty ? "primary" : "outline"}
                            size="sm"
                            disabled={!dirty}
                            onClick={() => save(g)}
                          >
                            <Save className="w-3.5 h-3.5" />
                            Save
                          </Button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}
