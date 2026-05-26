/**
 * Decorative phone-collage background for the Signup page.
 *
 * Layout mimics the Tinder marketing hero:
 *   • All phones share the same tilt (-14°) → reads as a single slanted plane
 *   • Brick-pattern grid, with alternate rows offset by half a column, so
 *     the tiles tessellate instead of leaving obvious gaps
 *   • Rich phone chrome (thick bezel, Dynamic Island, side buttons)
 *   • Tinder-style action row under every card: ↺ ✖ ⭐ ❤ ⚡
 *
 * Photos come from Unsplash (free commercial use). If a photo fails to
 * load the emoji + gradient fallback underneath keeps the tile lively.
 * Collage is pointer-events-none so it never intercepts clicks.
 */
import React, { useState } from "react";

// CDN helper — Unsplash image with face-centered crop and a sensible
// bandwidth budget. `auto=format` serves WebP on supported browsers.
const PH = (id) =>
  `https://images.unsplash.com/photo-${id}?auto=format&fit=crop&w=480&h=720&q=75&crop=faces`;

// Unique portrait pool. We only need ~20 distinct faces — the collage
// is built from a 7×6 brick grid (42 tiles), so names/photos cycle
// through this pool with slight name suffixes to avoid dupes on screen.
const POOL = [
  { name: "Sana",    age: 22, grad: "from-rose-300 via-pink-400 to-purple-600",       emoji: "😊", photo: PH("1529626455594-4ff0802cfb7e") },
  { name: "Priya",   age: 24, grad: "from-amber-300 via-orange-400 to-rose-500",      emoji: "✨", photo: PH("1524504388940-b1c1722653e1") },
  { name: "Apoorva", age: 22, grad: "from-pink-300 via-rose-400 to-red-500",          emoji: "💫", photo: PH("1601412436009-d964bd02edbc") },
  { name: "Prachi",  age: 23, grad: "from-teal-300 via-cyan-400 to-blue-500",         emoji: "🥰", photo: PH("1573496359142-b8d87734a5a2") },
  { name: "Kabir",   age: 28, grad: "from-indigo-300 via-violet-400 to-fuchsia-500",  emoji: "🎸", photo: PH("1506794778202-cad84cf45f1d") },
  { name: "Eshna",   age: 24, grad: "from-orange-300 via-pink-400 to-rose-500",       emoji: "✨", photo: PH("1534528741775-53994a69daeb") },
  { name: "Aanya",   age: 21, grad: "from-slate-400 via-blue-500 to-indigo-700",      emoji: "🌊", photo: PH("1607746882042-944635dfe10e") },
  { name: "Diya",    age: 25, grad: "from-yellow-300 via-amber-400 to-red-500",       emoji: "🌻", photo: PH("1614283233556-f35b0c801ef1") },
  { name: "Aarav",   age: 27, grad: "from-emerald-300 via-teal-400 to-cyan-600",      emoji: "🏀", photo: PH("1531891437562-4301cf35b7e4") },
  { name: "Shruti",  age: 21, grad: "from-fuchsia-300 via-pink-400 to-rose-600",      emoji: "🎨", photo: PH("1508214751196-bcfd4ca60f91") },
  { name: "Meera",   age: 23, grad: "from-rose-400 via-red-500 to-pink-700",          emoji: "💃", photo: PH("1438761681033-6461ffad8d80") },
  { name: "Ira",     age: 26, grad: "from-purple-300 via-fuchsia-400 to-pink-600",    emoji: "🌸", photo: PH("1488426862026-3ee34a7d66df") },
  { name: "Vikram",  age: 30, grad: "from-gray-400 via-slate-500 to-zinc-700",        emoji: "📸", photo: PH("1500648767791-00dcc994a43e") },
  { name: "Nisha",   age: 22, grad: "from-pink-400 via-rose-500 to-red-600",          emoji: "☕", photo: PH("1580489944761-15a19d654956") },
  { name: "Riya",    age: 25, grad: "from-sky-300 via-blue-400 to-indigo-600",        emoji: "🎧", photo: PH("1552699611-e2c208d5d9cf") },
  { name: "Tara",    age: 24, grad: "from-rose-300 via-pink-500 to-fuchsia-700",      emoji: "🌹", photo: PH("1548142813-c348350df52b") },
  { name: "Simran",  age: 23, grad: "from-amber-300 via-pink-400 to-violet-500",      emoji: "🌺", photo: PH("1517365830460-955ce3ccd263") },
  { name: "Kavya",   age: 22, grad: "from-pink-300 via-fuchsia-400 to-purple-500",    emoji: "🎀", photo: PH("1519340241574-2cec6aef0c01") },
  { name: "Rohan",   age: 26, grad: "from-cyan-400 via-blue-500 to-indigo-700",       emoji: "🏍", photo: PH("1517841905240-472988babdf9") },
  { name: "Anjali",  age: 25, grad: "from-fuchsia-400 via-rose-500 to-red-600",       emoji: "🌷", photo: PH("1509631179647-0177331693ae") },
];

// Build a dense 7×6 = 42-tile grid. We deliberately offset the pool
// index per row so repeated faces never sit next to each other.
const COLS = 7;
const ROWS = 6;
const TILES = [];
for (let i = 0; i < COLS * ROWS; i++) {
  const r = Math.floor(i / COLS);
  // Row-stride offset prevents duplicate photos appearing as vertical
  // neighbours (which is what the eye catches in repeating patterns).
  const poolIdx = (i + r * 3) % POOL.length;
  TILES.push(POOL[poolIdx]);
}


// Single phone with full action bar beneath. `offset` shifts alternate
// rows so the grid tessellates like a brick wall.
function PhoneCard({ name, age, grad, emoji, photo }) {
  const [photoState, setPhotoState] = useState("loading"); // loading | ok | failed

  return (
    <div className="select-none flex flex-col items-center">
      {/* Phone body — thick bezel, rounded device look */}
      <div className="relative w-[110px] h-[200px] md:w-[120px] md:h-[220px] rounded-[28px] bg-gradient-to-b from-gray-800 via-gray-950 to-black p-[3px] shadow-[0_20px_40px_-10px_rgba(0,0,0,0.8)] ring-1 ring-white/10">

        {/* Side buttons — power (right) + volume (left) */}
        <span className="absolute left-[-2px] top-16 w-[2px] h-7 bg-gray-700 rounded-l" />
        <span className="absolute left-[-2px] top-28 w-[2px] h-12 bg-gray-700 rounded-l" />
        <span className="absolute right-[-2px] top-20 w-[2px] h-10 bg-gray-700 rounded-r" />

        {/* Inner screen — rounded to follow bezel radius */}
        <div className={`relative w-full h-full rounded-[24px] overflow-hidden bg-gradient-to-br ${grad}`}>
          {/* Fallback emoji (shows through until photo loads) */}
          <div className="absolute inset-0 flex items-center justify-center text-5xl md:text-6xl opacity-90 drop-shadow-sm">
            {emoji}
          </div>

          {photo && photoState !== "failed" && (
            <img
              src={photo}
              alt=""
              loading="lazy"
              decoding="async"
              onLoad={() => setPhotoState("ok")}
              onError={() => setPhotoState("failed")}
              className={`absolute inset-0 w-full h-full object-cover transition-opacity duration-500 ${
                photoState === "ok" ? "opacity-100" : "opacity-0"
              }`}
            />
          )}

          {/* Top status bar area — time + signal dots */}
          <div className="absolute top-1 left-0 right-0 flex justify-between items-center px-3.5 text-white/85 text-[9px] font-bold">
            <span>9:41</span>
            <span className="flex items-center gap-0.5">
              <span className="w-1 h-1 bg-white/85 rounded-full" />
              <span className="w-1 h-1.5 bg-white/85 rounded-full" />
              <span className="w-1 h-2 bg-white/85 rounded-full" />
            </span>
          </div>

          {/* Dynamic Island — pill-shaped notch */}
          <div className="absolute top-1.5 left-1/2 -translate-x-1/2 w-14 h-4 rounded-full bg-black/80" />

          {/* Bottom gradient so name tag reads */}
          <div className="absolute inset-x-0 bottom-0 h-2/5 bg-gradient-to-t from-black/70 via-black/20 to-transparent" />

          {/* Name / age / verified tick */}
          <div className="absolute left-2.5 bottom-8 flex items-center gap-1.5">
            <span className="text-white text-[13px] font-black drop-shadow-md leading-none">
              {name} <span className="font-medium opacity-95">{age}</span>
            </span>
            <span className="w-3.5 h-3.5 rounded-full bg-sky-400 text-white text-[9px] flex items-center justify-center ring-1 ring-white/40 font-black">
              ✓
            </span>
          </div>

          {/* Small location chip */}
          <div className="absolute left-2.5 bottom-2 inline-flex items-center gap-1 text-white/90 text-[9px] font-semibold">
            <span>📍</span> Mumbai
          </div>

          {/* Home-indicator bar at bottom */}
          <div className="absolute bottom-[3px] left-1/2 -translate-x-1/2 w-10 h-[3px] rounded-full bg-white/60" />
        </div>
      </div>

      {/* ── Action row below the phone (Tinder-style) ────────────── */}
      <div className="mt-2 flex items-center gap-1.5">
        <ActionBtn bg="bg-amber-400" fg="text-amber-900" size="sm"  glyph="↺" />
        <ActionBtn bg="bg-white"      fg="text-rose-500" size="md"  glyph="✖" ring="ring-rose-200" />
        <ActionBtn bg="bg-white"      fg="text-sky-500"  size="sm"  glyph="★" ring="ring-sky-200" />
        <ActionBtn bg="bg-white"      fg="text-emerald-500" size="md" glyph="❤" ring="ring-emerald-200" />
        <ActionBtn bg="bg-violet-500" fg="text-white"   size="sm"  glyph="⚡" />
      </div>
    </div>
  );
}

function ActionBtn({ bg, fg, glyph, size = "md", ring = "" }) {
  const dim = size === "md" ? "w-7 h-7 text-sm" : "w-5 h-5 text-[10px]";
  return (
    <span
      className={`${dim} ${bg} ${fg} ${ring ? "ring-1 " + ring : ""} rounded-full flex items-center justify-center shadow-md font-bold`}
    >
      {glyph}
    </span>
  );
}


// Scattered accent glyphs in the negative space between rows for extra
// texture — kept subtle so they don't compete with the phones.
const GLYPHS = [
  { char: "❤",  x: "6%",  y: "8%",  color: "text-rose-400",    size: "text-2xl",  rot: -8  },
  { char: "⚡", x: "96%", y: "14%", color: "text-violet-400",  size: "text-2xl",  rot: 10  },
  { char: "★",  x: "2%",  y: "56%", color: "text-amber-400",   size: "text-xl",   rot: -12 },
  { char: "❤",  x: "98%", y: "62%", color: "text-pink-500",    size: "text-2xl",  rot: 6   },
  { char: "⚡", x: "4%",  y: "92%", color: "text-fuchsia-500", size: "text-xl",   rot: 8   },
  { char: "★",  x: "94%", y: "94%", color: "text-yellow-400",  size: "text-2xl",  rot: -6  },
];


export default function PhoneCollageBg() {
  return (
    <div
      aria-hidden="true"
      className="pointer-events-none absolute inset-0 overflow-hidden"
    >
      {/* Deep base — matches Tinder-style dark stage so phones pop */}
      <div className="absolute inset-0 bg-gradient-to-br from-gray-950 via-gray-900 to-black" />

      {/* Warm glow blobs */}
      <div className="absolute -top-24 -left-24 w-96 h-96 rounded-full bg-rose-500/25 blur-3xl" />
      <div className="absolute top-1/3 right-0 w-[28rem] h-[28rem] rounded-full bg-violet-500/20 blur-3xl" />
      <div className="absolute -bottom-32 left-1/3 w-[30rem] h-[30rem] rounded-full bg-pink-500/15 blur-3xl" />

      {/* The whole grid is rotated -14deg as a single layer so every
          phone shares the exact same tilt — matches the Tinder hero
          where the tilt itself creates the diagonal rhythm, not per-row
          offsets. Scale 1.6 ensures the rotated corners still cover the
          viewport at wide aspect ratios. */}
      <div
        className="absolute inset-0 flex items-center justify-center"
        style={{ transform: "rotate(-14deg) scale(1.6)", transformOrigin: "center" }}
      >
        <div
          className="grid gap-x-2 gap-y-3"
          style={{ gridTemplateColumns: `repeat(${COLS}, minmax(0, 1fr))` }}
        >
          {TILES.map((t, i) => (
            <PhoneCard key={i} {...t} />
          ))}
        </div>
      </div>

      {/* Scattered glyphs (sit above the grid but below the vignette) */}
      {GLYPHS.map((g, i) => (
        <span
          key={i}
          className={`absolute ${g.color} ${g.size} font-bold opacity-70 drop-shadow`}
          style={{ left: g.x, top: g.y, transform: `rotate(${g.rot}deg)` }}
        >
          {g.char}
        </span>
      ))}

      {/* Readability vignette — darker centre where the signup form sits. */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(0,0,0,0.6)_0%,rgba(0,0,0,0.3)_45%,transparent_78%)]" />
    </div>
  );
}
