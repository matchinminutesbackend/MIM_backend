/**
 * About page — MatchInMinutes company & leadership profile.
 *
 * Reachable from the Navbar's "About" link. Deliberately typography-driven
 * and imagery-free: the leadership cards use monogram initials rather
 * than stock photos so the page reads as a corporate "About us", not a
 * profile page.
 */
import { useNavigate } from "react-router-dom";
import {
  Target, ShieldCheck, Users, Globe, Sparkles, Heart, ArrowRight,
} from "lucide-react";
import Navbar from "../components/Navbar";
import Footer from "../components/Footer";

// Inline LinkedIn / X icons — lucide-react doesn't ship these in the
// installed version.
const LinkedinIcon = (props) => (
  <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
    <path d="M20.45 20.45h-3.55v-5.57c0-1.33-.03-3.04-1.86-3.04-1.86 0-2.14 1.45-2.14 2.95v5.66H9.35V9h3.41v1.56h.05c.47-.9 1.63-1.86 3.36-1.86 3.6 0 4.27 2.37 4.27 5.45v6.3zM5.34 7.43a2.06 2.06 0 1 1 0-4.12 2.06 2.06 0 0 1 0 4.12zM7.12 20.45H3.56V9h3.56v11.45z" />
  </svg>
);
const TwitterIcon = (props) => (
  <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
    <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
  </svg>
);

// ─── Copy ────────────────────────────────────────────────────────────
// Edit these objects to change the page content without touching layout.
const LEADERSHIP = [
  {
    name:     "Mr.X",
    role:     "Founder & Chief Executive Officer",
    initials: "NK",
    bio:
      "Mr.X founded MatchInMinutes in 2025 after a decade building consumer internet products. He leads the company's vision, product direction, and long-term strategy — with a singular belief that dating technology should give people their time back, not consume it.",
    links: {
      linkedin: "https://www.linkedin.com/",
      twitter:  "https://twitter.com/",
    },
  },
  {
    name:     "Mr.Y",
    role:     "Co-founder & Head of Trust & Safety",
    initials: "PI",
    bio:
      "Mr.Y oversees verification, moderation, and community policy. She leads the team that keeps the MatchInMinutes community authentic, respectful, and secure — from onboarding checks to in-app moderation.",
    links: {
      linkedin: "https://www.linkedin.com/",
      twitter:  "https://twitter.com/",
    },
  },
];

const VALUES = [
  {
    Icon: ShieldCheck,
    title: "Safety by design",
    body:
      "Every profile is verified. Every report is reviewed. Our product decisions default to protecting our users — even when that costs us growth.",
  },
  {
    Icon: Heart,
    title: "Genuine connection",
    body:
      "We are measured by the conversations our members start, not the swipes they make. The product is designed to reward quality over volume.",
  },
  {
    Icon: Users,
    title: "Respect for the user",
    body:
      "Our members trust us with sensitive personal data. We treat that trust as a contract — no dark patterns, no sold data, no surprises.",
  },
  {
    Icon: Globe,
    title: "Built in India, built for the world",
    body:
      "Headquartered in Chennai, serving members across India and abroad. We design for every culture and every kind of serious relationship.",
  },
];

const MILESTONES = [
  { year: "Jan 2025", title: "Company founded",       body: "Incorporated in Chennai with a small founding team." },
  { year: "Apr 2025", title: "Closed alpha",          body: "Invite-only rollout to a handpicked group of early users." },
  { year: "Jul 2025", title: "Public beta",           body: "Opened signups across select Indian metros with verified profiles." },
  { year: "2026",      title: "Voice & video calling", body: "Shipped in-app calling for premium members." },
];

// Startup-honest numbers. Kept small and truthful — no inflated metrics.
const FACTS = [
  { label: "Headquarters", value: "Chennai, India" },
  { label: "Founded",      value: "2025" },
  { label: "Team",         value: "8+" },
  { label: "Stage",        value: "Early access" },
];

// ─── Page ────────────────────────────────────────────────────────────
export default function About() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-[#0b0b18] text-white">
      <Navbar />

      {/* ── HERO — typography-only ───────────────────────────────── */}
      <section className="px-6 md:px-8 pt-16 pb-20 border-b border-white/5">
        <div className="max-w-4xl mx-auto">
          <div className="inline-flex items-center gap-2 text-pink-400 text-xs font-semibold tracking-widest uppercase mb-6">
            <Sparkles size={12} /> About the company
          </div>
          <h1 className="text-4xl md:text-6xl font-extrabold leading-[1.1] tracking-tight mb-6">
            Building a dating platform<br className="hidden md:inline" />
            <span className="text-gray-400"> worthy of its members.</span>
          </h1>
          <p className="text-lg text-gray-400 leading-relaxed max-w-2xl">
            MatchInMinutes is a Chennai-based company creating technology that helps serious singles
            find meaningful relationships — faster, safer, and with more dignity than the current
            generation of dating products allows for.
          </p>
        </div>
      </section>

      {/* ── MISSION STATEMENT ────────────────────────────────────── */}
      <section className="px-6 md:px-8 py-20">
        <div className="max-w-4xl mx-auto grid md:grid-cols-3 gap-10">
          <div className="md:col-span-1">
            <p className="text-xs font-semibold tracking-widest uppercase text-gray-500">Our Mission</p>
          </div>
          <div className="md:col-span-2">
            <p className="text-2xl md:text-3xl font-semibold leading-snug text-white">
              To help every member start a real conversation with someone who fits their life —
              in <span className="text-pink-400">minutes</span>, not months.
            </p>
            <p className="mt-6 text-gray-400 leading-relaxed">
              We believe the dating industry has optimised for the wrong outcomes: endless swiping,
              shallow signals, and retention metrics that reward time spent on an app over the
              quality of the relationships that come out of it. We are building the opposite of
              that — a product our members use briefly, deliberately, and successfully.
            </p>
          </div>
        </div>
      </section>

      {/* ── LEADERSHIP — no photos, monogram initials ────────────── */}
      <section className="px-6 md:px-8 py-20 border-t border-white/5">
        <div className="max-w-5xl mx-auto">
          <div className="mb-12">
            <p className="text-xs font-semibold tracking-widest uppercase text-gray-500 mb-3">Leadership</p>
            <h2 className="text-3xl md:text-4xl font-extrabold tracking-tight">
              The people responsible for the company.
            </h2>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            {LEADERSHIP.map((p) => (
              <article
                key={p.name}
                className="bg-[#0f0f22] border border-white/10 rounded-2xl p-8 hover:border-pink-500/30 transition-colors"
              >
                <div className="flex items-start gap-5">
                  {/* Monogram instead of a photo — keeps the page imagery-free */}
                  <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-pink-500/20 to-purple-500/20 border border-pink-500/30 flex items-center justify-center flex-shrink-0">
                    <span className="text-pink-300 font-bold tracking-wider">{p.initials}</span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold">{p.name}</h3>
                    <p className="text-sm text-pink-400 mt-0.5">{p.role}</p>
                  </div>
                </div>
                <p className="mt-5 text-gray-400 text-sm leading-relaxed">{p.bio}</p>
                <div className="mt-5 flex items-center gap-2">
                  <a
                    href={p.links.linkedin} target="_blank" rel="noreferrer" aria-label={`${p.name} on LinkedIn`}
                    className="w-9 h-9 rounded-lg bg-[#13132a] border border-white/10 flex items-center justify-center text-gray-400 hover:text-pink-400 hover:border-pink-500/40 transition-colors"
                  >
                    <LinkedinIcon width={15} height={15} />
                  </a>
                  <a
                    href={p.links.twitter} target="_blank" rel="noreferrer" aria-label={`${p.name} on X`}
                    className="w-9 h-9 rounded-lg bg-[#13132a] border border-white/10 flex items-center justify-center text-gray-400 hover:text-pink-400 hover:border-pink-500/40 transition-colors"
                  >
                    <TwitterIcon width={15} height={15} />
                  </a>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* ── VALUES ───────────────────────────────────────────────── */}
      <section className="px-6 md:px-8 py-20 border-t border-white/5">
        <div className="max-w-5xl mx-auto">
          <div className="mb-12">
            <p className="text-xs font-semibold tracking-widest uppercase text-gray-500 mb-3">Principles</p>
            <h2 className="text-3xl md:text-4xl font-extrabold tracking-tight">
              Four commitments we do not compromise on.
            </h2>
          </div>
          <div className="grid md:grid-cols-2 gap-px bg-white/10 rounded-2xl overflow-hidden border border-white/10">
            {VALUES.map(({ Icon, title, body }) => (
              <div key={title} className="bg-[#0b0b18] p-8 hover:bg-[#0f0f22] transition-colors">
                <div className="flex items-center gap-3 mb-3">
                  <Icon size={18} className="text-pink-400" />
                  <h3 className="text-lg font-bold">{title}</h3>
                </div>
                <p className="text-gray-400 text-sm leading-relaxed">{body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── MILESTONES / COMPANY TIMELINE ───────────────────────── */}
      <section className="px-6 md:px-8 py-20 border-t border-white/5">
        <div className="max-w-4xl mx-auto">
          <div className="mb-12">
            <p className="text-xs font-semibold tracking-widest uppercase text-gray-500 mb-3">Milestones</p>
            <h2 className="text-3xl md:text-4xl font-extrabold tracking-tight">
              A short history.
            </h2>
          </div>
          <ol className="relative border-l border-white/10 ml-2 space-y-10">
            {MILESTONES.map((m, i) => (
              <li key={i} className="pl-8 relative">
                <span className="absolute -left-[7px] top-1.5 w-3 h-3 rounded-full bg-pink-500 ring-4 ring-[#0b0b18]" />
                <p className="text-xs font-semibold tracking-widest uppercase text-pink-400 mb-1">{m.year}</p>
                <h3 className="text-lg font-bold mb-1">{m.title}</h3>
                <p className="text-gray-400 text-sm leading-relaxed">{m.body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* ── COMPANY FACTS ───────────────────────────────────────── */}
      <section className="px-6 md:px-8 py-20 border-t border-white/5">
        <div className="max-w-5xl mx-auto">
          <div className="mb-10">
            <p className="text-xs font-semibold tracking-widest uppercase text-gray-500 mb-3">At a glance</p>
            <h2 className="text-3xl md:text-4xl font-extrabold tracking-tight">Company facts.</h2>
          </div>
          <dl className="grid grid-cols-2 md:grid-cols-4 border border-white/10 rounded-2xl overflow-hidden">
            {FACTS.map((f, i) => (
              <div key={f.label}
                className={`p-6 md:p-8 bg-[#0f0f22] ${i !== FACTS.length - 1 ? "md:border-r border-white/10" : ""}`}
              >
                <dt className="text-xs font-semibold tracking-widest uppercase text-gray-500">{f.label}</dt>
                <dd className="mt-2 text-2xl md:text-3xl font-extrabold text-white">{f.value}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>

      {/* ── CTA ─────────────────────────────────────────────────── */}
      <section className="px-6 md:px-8 py-24 border-t border-white/5">
        <div className="max-w-4xl mx-auto flex flex-col md:flex-row items-start md:items-center justify-between gap-8">
          <div>
            <h2 className="text-3xl md:text-4xl font-extrabold tracking-tight mb-2">
              Join the community.
            </h2>
            <p className="text-gray-400">Signing up takes less than a minute and is free.</p>
          </div>
          <button
            onClick={() => navigate("/signup")}
            className="inline-flex items-center gap-2 bg-white text-gray-900 font-semibold px-7 py-3.5 rounded-full hover:bg-gray-200 transition-colors whitespace-nowrap"
          >
            Create an account <ArrowRight size={16} />
          </button>
        </div>
      </section>

      <Footer />
    </div>
  );
}
