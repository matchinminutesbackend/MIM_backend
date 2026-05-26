/**
 * CompatibilitySection
 *
 * Mirrors the Flutter CompatibilitySection widget exactly.
 * • Display mode  — horizontal scrollable answer cards
 * • Edit mode     — modal with all 10 questions for the user's goal,
 *                   option chips to pick one answer per question,
 *                   saved via PATCH /profile/me
 */
import { useState } from "react";
import { Plus, Pencil, X, Check } from "lucide-react";
import { api } from "../api/client";

// ── Question data (mirrors compatibility_questions.dart) ─────────────────────

const LONG_TERM = [
  { id: "lt_commitment", q: "How do you approach commitment?",        opts: ["I take time, then commit fully", "I know pretty quickly", "I let it grow naturally"] },
  { id: "lt_kids",       q: "How do you feel about having kids?",     opts: ["I want kids", "I don't want kids", "I'm unsure", "I already have kids"] },
  { id: "lt_marriage",   q: "What's your view on marriage?",          opts: ["Fully open to it", "Open but flexible", "Not for me"] },
  { id: "lt_5years",     q: "Where do you see yourself in 5 years?",  opts: ["Settled down", "Career focused", "Still exploring", "Not sure"] },
  { id: "lt_conflict",   q: "How do you handle conflict?",            opts: ["Talk it out immediately", "Need space first", "Calm and direct"] },
  { id: "lt_lovelang",   q: "What's your love language?",             opts: ["Quality time", "Physical touch", "Words of affirmation", "Acts of service"] },
  { id: "lt_living",     q: "Living together — when?",                opts: ["After marriage", "Before marriage to test", "Open to either"] },
  { id: "lt_finances",   q: "How do you handle finances as a couple?",opts: ["Combine everything", "Keep it separate", "Figure it out together"] },
  { id: "lt_settle",     q: "How soon do you want to settle down?",   opts: ["Within a year", "1–3 years", "No rush"] },
  { id: "lt_religion",   q: "Religion in a relationship?",            opts: ["Very important — must match", "Somewhat important", "Doesn't matter to me"] },
];

const SHORT_TERM = [
  { id: "st_looking",   q: "What are you looking for right now?", opts: ["Fun & adventure", "Meaningful connection", "Both"] },
  { id: "st_start",     q: "How do you start a connection?",      opts: ["Jump right in", "Take it slow", "Go with the flow"] },
  { id: "st_exclusive", q: "Exclusivity?",                         opts: ["Open to it if it feels right", "Not looking for it", "Prefer to keep it open"] },
  { id: "st_weekend",   q: "Your weekend vibe?",                   opts: ["Outdoor adventures", "Cozy nights in", "Social scenes", "Spontaneous"] },
  { id: "st_comms",     q: "Communication style?",                 opts: ["Text all day", "Check in occasionally", "Voice calls", "Quality over quantity"] },
  { id: "st_firstdate", q: "First date idea?",                     opts: ["Dinner out", "Coffee & walk", "Adventure activity", "Chill at home"] },
  { id: "st_care",      q: "How do you show you care?",            opts: ["Compliments", "Quality time", "Small gestures", "Physical affection"] },
  { id: "st_friends",   q: "Meeting friends — when?",              opts: ["Early on", "After some time", "Keep it separate for now"] },
  { id: "st_social",    q: "Your social life?",                    opts: ["Very social", "Balanced", "Mostly private"] },
  { id: "st_greenflag", q: "Biggest green flag?",                  opts: ["Good listener", "Makes me laugh", "Ambitious", "Emotionally available"] },
];

const FRIENDSHIP = [
  { id: "fr_make",      q: "How do you make new friends?",      opts: ["Easily — I talk to everyone", "Takes time", "Through shared interests"] },
  { id: "fr_value",     q: "What do you value most?",           opts: ["Loyalty", "Humor", "Deep conversations", "Shared hobbies"] },
  { id: "fr_circle",    q: "Your friend circle?",               opts: ["Big and social", "Small and close", "One-on-one connections"] },
  { id: "fr_openup",    q: "How long to open up?",              opts: ["Pretty quickly", "Takes some time", "Takes a while"] },
  { id: "fr_hangout",   q: "Ideal hangout?",                    opts: ["Group outings", "One-on-one", "Online / gaming", "Mix of all"] },
  { id: "fr_care",      q: "How do you show you care?",         opts: ["Regular check-ins", "Acts of kindness", "Just being there", "Listening"] },
  { id: "fr_conflict",  q: "Conflict in friendship?",           opts: ["Talk it out directly", "Give it time", "Open communication"] },
  { id: "fr_intro",     q: "Are you?",                          opts: ["Introvert", "Extrovert", "Ambivert"] },
  { id: "fr_bring",     q: "You bring to a friendship:",        opts: ["Loyalty", "Fun energy", "Emotional support", "Adventures"] },
  { id: "fr_socialize", q: "Your love for socializing?",        opts: ["Always up for plans", "Need notice first", "Homebody mostly"] },
];

function questionsForGoal(goal) {
  if (goal === "short_term" || goal === "casual") return SHORT_TERM;
  if (goal === "friendship") return FRIENDSHIP;
  return LONG_TERM; // default: long_term / marriage / unsure
}

function sectionTitle(goal) {
  if (goal === "short_term" || goal === "casual") return "Connection Style";
  if (goal === "friendship") return "Friendship Compatibility";
  return "Long-term Compatibility";
}

// ── Main exported component ──────────────────────────────────────────────────

export default function CompatibilitySection({ profile, onSaved }) {
  const [open, setOpen] = useState(false);

  const answers = profile?.compatibility_answers || [];
  const goal    = profile?.relationship_goal || "";
  const title   = sectionTitle(goal);
  const answered = answers.length;

  return (
    <>
      {/* ── Section card ── */}
      <section className="bg-white rounded-3xl shadow-sm border border-rose-100/60 p-4 md:p-5">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h3 className="font-bold text-gray-900 text-sm">{title}</h3>
            {answered > 0 && (
              <p className="text-xs text-gray-400 mt-0.5">{answered}/10 answered</p>
            )}
          </div>
          <button
            onClick={() => setOpen(true)}
            className="inline-flex items-center gap-1 text-xs font-semibold text-pink-500 hover:text-pink-600 transition"
          >
            {answered > 0 ? <><Pencil size={12} /> Edit</> : <><Plus size={13} /> Add</>}
          </button>
        </div>

        {answered === 0 ? (
          /* Empty state */
          <button
            onClick={() => setOpen(true)}
            className="w-full py-8 border-2 border-dashed border-rose-200 rounded-2xl flex flex-col items-center gap-2 text-gray-400 hover:border-pink-400 hover:text-pink-500 transition"
          >
            <span className="text-2xl">💬</span>
            <span className="text-sm font-medium">Answer compatibility questions</span>
            <span className="text-xs text-gray-400">Help matches understand you better</span>
          </button>
        ) : (
          /* Scrollable answer cards */
          <div className="flex gap-3 overflow-x-auto pb-1 -mx-1 px-1 snap-x snap-mandatory">
            {answers.map((a, i) => (
              <div
                key={i}
                className="flex-shrink-0 snap-start w-44 bg-gradient-to-br from-rose-50 to-pink-50 border border-rose-100 rounded-2xl p-3.5 flex flex-col gap-2"
              >
                <p className="text-[11px] text-gray-500 leading-snug line-clamp-3 font-medium">
                  {a.question}
                </p>
                <p className="text-xs font-bold text-pink-600 leading-snug line-clamp-2 mt-auto">
                  {a.answer}
                </p>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* ── Edit modal ── */}
      {open && (
        <CompatibilityModal
          goal={goal}
          existing={answers}
          onClose={() => setOpen(false)}
          onSaved={(updated) => { onSaved(updated); setOpen(false); }}
        />
      )}
    </>
  );
}

// ── Modal ────────────────────────────────────────────────────────────────────

function CompatibilityModal({ goal, existing, onClose, onSaved }) {
  const questions = questionsForGoal(goal);

  // Build initial state from existing answers
  const initialMap = {};
  existing.forEach(a => {
    const q = questions.find(q => q.q === a.question);
    if (q) initialMap[q.id] = a.answer;
  });

  const [selected, setSelected] = useState(initialMap);
  const [saving, setSaving]     = useState(false);
  const [err, setErr]           = useState("");

  const answeredCount = Object.keys(selected).length;

  function toggle(qId, opt) {
    setSelected(prev =>
      prev[qId] === opt
        ? (() => { const n = { ...prev }; delete n[qId]; return n; })()
        : { ...prev, [qId]: opt }
    );
  }

  async function save() {
    setSaving(true);
    setErr("");
    try {
      const answers = questions
        .filter(q => selected[q.id])
        .map(q => ({ question: q.q, answer: selected[q.id] }));
      await api.profile.update({ compatibility_answers: answers });
      onSaved(answers);
    } catch (e) {
      setErr(e.message || "Failed to save");
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />

      {/* Sheet */}
      <div className="relative z-10 w-full sm:max-w-lg bg-white sm:rounded-3xl rounded-t-3xl shadow-2xl flex flex-col max-h-[90vh]">

        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-5 pb-3 border-b border-gray-100 flex-shrink-0">
          <div>
            <h2 className="font-bold text-gray-900 text-base">{sectionTitle(goal)}</h2>
            <p className="text-xs text-gray-400 mt-0.5">{answeredCount}/10 answered</p>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-full hover:bg-gray-100 transition">
            <X size={18} className="text-gray-500" />
          </button>
        </div>

        {/* Progress bar */}
        <div className="h-1 bg-gray-100 flex-shrink-0">
          <div
            className="h-full bg-gradient-to-r from-pink-500 to-rose-500 transition-all duration-300"
            style={{ width: `${(answeredCount / 10) * 100}%` }}
          />
        </div>

        {/* Questions list */}
        <div className="overflow-y-auto flex-1 px-5 py-4 space-y-6">
          {questions.map((q, idx) => (
            <div key={q.id}>
              <p className="text-sm font-semibold text-gray-800 mb-2.5">
                <span className="text-pink-400 mr-1.5">{idx + 1}.</span>
                {q.q}
              </p>
              <div className="flex flex-wrap gap-2">
                {q.opts.map(opt => {
                  const active = selected[q.id] === opt;
                  return (
                    <button
                      key={opt}
                      onClick={() => toggle(q.id, opt)}
                      className={`px-3.5 py-1.5 rounded-full text-xs font-medium border transition-all ${
                        active
                          ? "bg-pink-500 border-pink-500 text-white shadow-sm"
                          : "bg-white border-gray-200 text-gray-600 hover:border-pink-300 hover:text-pink-500"
                      }`}
                    >
                      {active && <Check size={10} className="inline mr-1" />}
                      {opt}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>

        {/* Footer */}
        {err && <p className="text-xs text-red-500 px-5 pb-1">{err}</p>}
        <div className="px-5 py-4 border-t border-gray-100 flex-shrink-0">
          <button
            onClick={save}
            disabled={saving || answeredCount === 0}
            className="w-full bg-gradient-to-r from-pink-500 to-rose-500 text-white font-bold py-3 rounded-2xl text-sm disabled:opacity-50 hover:opacity-90 transition flex items-center justify-center gap-2"
          >
            {saving ? "Saving…" : `Save answers (${answeredCount}/10)`}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Read-only view for other users' profiles (matches / discover) ────────────

export function CompatibilityAnswersView({ answers = [], goal }) {
  if (!answers.length) return null;
  const title = sectionTitle(goal);

  return (
    <div>
      <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">{title}</p>
      <div className="flex gap-3 overflow-x-auto pb-1 snap-x snap-mandatory">
        {answers.map((a, i) => (
          <div
            key={i}
            className="flex-shrink-0 snap-start w-44 bg-gradient-to-br from-rose-50 to-pink-50 border border-rose-100 rounded-2xl p-3.5 flex flex-col gap-2"
          >
            <p className="text-[11px] text-gray-500 leading-snug line-clamp-3 font-medium">{a.question}</p>
            <p className="text-xs font-bold text-pink-600 leading-snug line-clamp-2 mt-auto">{a.answer}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
