import { motion } from "framer-motion";
import { Heart, ArrowRight, Star, Search } from "lucide-react";
import { useNavigate } from "react-router-dom";

// Smaller images — 320×480 at q60 loads fast, still crisp at 108px wide
const PH = (id) =>
  `https://images.unsplash.com/photo-${id}?auto=format&fit=crop&w=320&h=480&q=60&crop=faces`;

// 24 distinct faces — 8 per row, zero overlap between rows
const POOL = [
  // Row A (0-7)
  { name: "Sana",    age: 22, grad: "from-rose-300 via-pink-400 to-purple-600",      emoji: "😊", photo: PH("1529626455594-4ff0802cfb7e") },
  { name: "Priya",   age: 24, grad: "from-amber-300 via-orange-400 to-rose-500",     emoji: "✨", photo: PH("1524504388940-b1c1722653e1") },
  { name: "Apoorva", age: 22, grad: "from-pink-300 via-rose-400 to-red-500",         emoji: "💫", photo: PH("1601412436009-d964bd02edbc") },
  { name: "Prachi",  age: 23, grad: "from-teal-300 via-cyan-400 to-blue-500",        emoji: "🥰", photo: PH("1573496359142-b8d87734a5a2") },
  { name: "Kabir",   age: 28, grad: "from-indigo-300 via-violet-400 to-fuchsia-500", emoji: "🎸", photo: PH("1506794778202-cad84cf45f1d") },
  { name: "Eshna",   age: 24, grad: "from-orange-300 via-pink-400 to-rose-500",      emoji: "✨", photo: PH("1534528741775-53994a69daeb") },
  { name: "Aanya",   age: 21, grad: "from-slate-400 via-blue-500 to-indigo-700",     emoji: "🌊", photo: PH("1607746882042-944635dfe10e") },
  { name: "Durga",    age: 25, grad: "from-yellow-300 via-amber-400 to-red-500",      emoji: "🌻", photo: PH("1614283233556-f35b0c801ef1") },
  // Row B (8-15)
  { name: "Aarav",   age: 27, grad: "from-emerald-300 via-teal-400 to-cyan-600",     emoji: "🏀", photo: PH("1531891437562-4301cf35b7e4") },
  { name: "Shruti",  age: 21, grad: "from-fuchsia-300 via-pink-400 to-rose-600",     emoji: "🎨", photo: PH("1508214751196-bcfd4ca60f91") },
  { name: "Meera",   age: 23, grad: "from-rose-400 via-red-500 to-pink-700",         emoji: "💃", photo: PH("1438761681033-6461ffad8d80") },
  { name: "Ira",     age: 26, grad: "from-purple-300 via-fuchsia-400 to-pink-600",   emoji: "🌸", photo: PH("1488426862026-3ee34a7d66df") },
  { name: "Vikram",  age: 30, grad: "from-gray-400 via-slate-500 to-zinc-700",       emoji: "📸", photo: PH("1500648767791-00dcc994a43e") },
  { name: "Nisha",   age: 22, grad: "from-pink-400 via-rose-500 to-red-600",         emoji: "☕", photo: PH("1580489944761-15a19d654956") },
  { name: "Riya",    age: 25, grad: "from-sky-300 via-blue-400 to-indigo-600",       emoji: "🎧", photo: PH("1552699611-e2c208d5d9cf") },
  { name: "Tara",    age: 24, grad: "from-rose-300 via-pink-500 to-fuchsia-700",     emoji: "🌹", photo: PH("1548142813-c348350df52b") },
  // Row C (16-23)
  { name: "Simran",  age: 23, grad: "from-amber-300 via-pink-400 to-violet-500",     emoji: "🌺", photo: PH("1517365830460-955ce3ccd263") },
  { name: "Kavya",   age: 22, grad: "from-pink-300 via-fuchsia-400 to-purple-500",   emoji: "🎀", photo: PH("1519340241574-2cec6aef0c01") },
  { name: "Rohan",   age: 26, grad: "from-cyan-400 via-blue-500 to-indigo-700",      emoji: "🏍", photo: PH("1517841905240-472988babdf9") },
  { name: "Anjali",  age: 25, grad: "from-fuchsia-400 via-rose-500 to-red-600",      emoji: "🌷", photo: PH("1509631179647-0177331693ae") },
  { name: "Dev",     age: 27, grad: "from-green-300 via-teal-400 to-cyan-600",       emoji: "🎯", photo: PH("1531891437562-4301cf35b7e4") },
  { name: "Pooja",   age: 23, grad: "from-rose-200 via-pink-300 to-fuchsia-500",     emoji: "🌷", photo: PH("1614283233556-f35b0c801ef1") },
  { name: "Arjun",   age: 29, grad: "from-blue-400 via-indigo-500 to-violet-700",    emoji: "🏄", photo: PH("1500648767791-00dcc994a43e") },
  { name: "Zara",    age: 24, grad: "from-pink-300 via-rose-400 to-red-600",         emoji: "🌹", photo: PH("1580489944761-15a19d654956") },
];

const ROW_A = POOL.slice(0, 8);
const ROW_B = POOL.slice(8, 16);
const ROW_C = POOL.slice(16, 24);

// No per-card state — emoji gradient shows while photo loads (it's beneath the img)
function PhoneCard({ name, age, grad, emoji, photo }) {
  return (
    <div className="select-none flex-shrink-0 w-[108px]">
      {/* Phone chassis */}
      <div className="relative w-[108px] h-[190px] rounded-[26px] bg-gradient-to-b from-gray-800 via-gray-950 to-black p-[3px] shadow-[0_14px_28px_-8px_rgba(0,0,0,0.85)] ring-1 ring-white/10">
        {/* Side buttons */}
        <span className="absolute left-[-2px] top-14 w-[2px] h-6 bg-gray-700 rounded-l" />
        <span className="absolute left-[-2px] top-24 w-[2px] h-9 bg-gray-700 rounded-l" />
        <span className="absolute right-[-2px] top-[70px] w-[2px] h-9 bg-gray-700 rounded-r" />

        {/* Screen */}
        <div className={`relative w-full h-full rounded-[22px] overflow-hidden bg-gradient-to-br ${grad}`}>
          {/* Emoji — always visible, acts as placeholder under the photo */}
          <div className="absolute inset-0 flex items-center justify-center text-4xl opacity-90 select-none">
            {emoji}
          </div>

          {/* Photo loads over the emoji; no JS state needed */}
          <img
            src={photo}
            alt=""
            loading="lazy"
            decoding="async"
            className="absolute inset-0 w-full h-full object-cover"
          />

          {/* Status bar */}
          <div className="absolute top-1 left-0 right-0 flex justify-between items-center px-3 text-white/85 text-[8px] font-bold">
            <span>9:41</span>
            <span className="flex items-center gap-0.5">
              <span className="w-1 h-1 bg-white/85 rounded-full" />
              <span className="w-1 h-1.5 bg-white/85 rounded-full" />
              <span className="w-1 h-2 bg-white/85 rounded-full" />
            </span>
          </div>

          {/* Dynamic Island */}
          <div className="absolute top-1.5 left-1/2 -translate-x-1/2 w-11 h-3.5 rounded-full bg-black/85" />

          {/* Bottom gradient */}
          <div className="absolute inset-x-0 bottom-0 h-2/5 bg-gradient-to-t from-black/75 via-black/20 to-transparent" />

          {/* Name + verified badge */}
          <div className="absolute left-2 bottom-6 flex items-center gap-1">
            <span className="text-white text-[11px] font-black drop-shadow-md leading-none">
              {name} <span className="font-medium opacity-90">{age}</span>
            </span>
            <span className="w-3 h-3 rounded-full bg-sky-400 text-white text-[8px] flex items-center justify-center font-black flex-shrink-0">
              ✓
            </span>
          </div>

          {/* Location chip */}
          <div className="absolute left-2 bottom-1.5 text-white/75 text-[8px] font-semibold">
            📍 Mumbai
          </div>

          {/* Home indicator */}
          <div className="absolute bottom-[3px] left-1/2 -translate-x-1/2 w-8 h-[3px] rounded-full bg-white/55" />
        </div>
      </div>

      {/* Tinder-style action row */}
      <div className="mt-1.5 flex items-center justify-center gap-1">
        <span className="w-5 h-5 rounded-full bg-amber-400 text-amber-900 text-[9px] flex items-center justify-center shadow font-bold">↺</span>
        <span className="w-6 h-6 rounded-full bg-white text-rose-500 text-[10px] flex items-center justify-center shadow ring-1 ring-rose-200 font-bold">✖</span>
        <span className="w-5 h-5 rounded-full bg-white text-sky-500 text-[9px] flex items-center justify-center shadow ring-1 ring-sky-200 font-bold">★</span>
        <span className="w-6 h-6 rounded-full bg-white text-emerald-500 text-[10px] flex items-center justify-center shadow ring-1 ring-emerald-200 font-bold">❤</span>
        <span className="w-5 h-5 rounded-full bg-violet-500 text-white text-[9px] flex items-center justify-center shadow font-bold">⚡</span>
      </div>
    </div>
  );
}

// Pure CSS marquee — runs on the compositor, zero JS overhead while scrolling
function MarqueeRow({ phones, reverse = false, duration = "38s" }) {
  // Duplicate once → animate translateX(-50%) = exactly one copy width
  const items = [...phones, ...phones];
  return (
    <div className="overflow-hidden">
      <div
        className={reverse ? "marquee-right" : "marquee-left"}
        style={{ display: "flex", gap: "12px", width: "max-content", animationDuration: duration }}
      >
        {items.map((p, i) => (
          <PhoneCard key={i} {...p} />
        ))}
      </div>
    </div>
  );
}

export default function HeroSection() {
  const navigate = useNavigate();

  return (
    <section className="relative min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-black overflow-hidden flex flex-col">

      {/* Ambient glow blobs */}
      <div className="absolute -top-40 -left-40 w-[520px] h-[520px] rounded-full bg-rose-500/20 blur-3xl pointer-events-none" />
      <div className="absolute top-1/2 -right-20 w-[400px] h-[400px] rounded-full bg-violet-500/15 blur-3xl pointer-events-none" />
      <div className="absolute -bottom-32 left-1/4 w-[380px] h-[380px] rounded-full bg-pink-500/12 blur-3xl pointer-events-none" />

      {/* ── Main content ── */}
      <div className="relative z-10 flex flex-1 flex-col lg:flex-row items-center pt-20 lg:pt-0">

        {/* LEFT: copy */}
        <div className="flex-shrink-0 w-full lg:w-[48%] xl:w-[44%] px-6 sm:px-10 lg:px-14 xl:px-20 py-12 lg:py-0 text-center lg:text-left">

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="inline-flex items-center gap-2 bg-pink-500/10 border border-pink-500/30 text-pink-400 text-xs font-semibold px-4 py-2 rounded-full mb-6"
          >
            <Heart size={12} className="fill-pink-400" />
            Over 8.6 Million Singles Online
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="text-white font-extrabold text-4xl sm:text-5xl lg:text-[3.4rem] xl:text-6xl leading-[1.08] mb-5 tracking-tight"
          >
            Meet People Who{" "}
            <span className="block text-transparent bg-clip-text bg-gradient-to-r from-pink-400 via-rose-400 to-fuchsia-400">
              Feel Like Home
            </span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-gray-400 text-base leading-relaxed mb-8 sm:mb-10 max-w-md mx-auto lg:mx-0"
          >
            Genuine profiles, shared values, and conversations that actually
            go somewhere — built for singles who want something real.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.3 }}
            className="flex items-center gap-3 flex-wrap justify-center lg:justify-start"
          >
            <button
              onClick={() => navigate("/signup")}
              className="flex items-center gap-2 bg-gradient-to-r from-pink-600 to-fuchsia-600 text-white font-bold px-7 py-3.5 rounded-full shadow-xl shadow-pink-700/30 hover:shadow-pink-600/50 hover:scale-105 transition-all duration-200 text-sm"
            >
              Get Started Free
              <ArrowRight size={16} />
            </button>
            <button
              onClick={() => navigate("/login")}
              className="flex items-center gap-2 text-white font-semibold px-6 py-3.5 rounded-full border border-gray-700 hover:border-pink-500/50 hover:bg-white/5 transition-all duration-200 text-sm"
            >
              <Search size={15} className="text-pink-400" />
              Browse Profiles
            </button>
          </motion.div>

          {/* Trust row */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6, delay: 0.55 }}
            className="flex items-center justify-center lg:justify-start gap-4 mt-9"
          >
            <div className="flex -space-x-2">
              {POOL.slice(0, 4).map((p, i) => (
                <img
                  key={i}
                  src={p.photo}
                  className="w-8 h-8 rounded-full border-2 border-gray-950 object-cover"
                  alt=""
                />
              ))}
            </div>
            <div>
              <div className="flex items-center gap-0.5">
                {[...Array(5)].map((_, i) => (
                  <Star key={i} size={11} className="fill-yellow-400 text-yellow-400" />
                ))}
                <span className="text-yellow-400 text-xs font-bold ml-1">4.9</span>
              </div>
              <p className="text-gray-500 text-xs mt-0.5">Trusted by 8.6M+ singles</p>
            </div>
          </motion.div>
        </div>

        {/* RIGHT: phone lanes — desktop only */}
        <div className="hidden lg:flex flex-1 self-stretch items-center overflow-hidden relative min-w-0">
          {/* Edge fades */}
          <div className="absolute inset-y-0 left-0 w-20 bg-gradient-to-r from-gray-950 to-transparent z-10 pointer-events-none" />
          <div className="absolute inset-y-0 right-0 w-10 bg-gradient-to-l from-gray-950/50 to-transparent z-10 pointer-events-none" />
          <div className="absolute inset-x-0 top-0 h-28 bg-gradient-to-b from-gray-950 to-transparent z-10 pointer-events-none" />
          <div className="absolute inset-x-0 bottom-0 h-28 bg-gradient-to-t from-gray-950 to-transparent z-10 pointer-events-none" />

          <div className="flex flex-col gap-5 w-full pointer-events-none">
            <MarqueeRow phones={ROW_A} duration="32s" />
            <MarqueeRow phones={ROW_B} reverse duration="28s" />
            <MarqueeRow phones={ROW_C} duration="36s" />
          </div>
        </div>
      </div>

      {/* Mobile: 2-row strip below copy */}
      <div className="lg:hidden relative overflow-hidden pb-8 pt-1">
        <div className="absolute inset-y-0 left-0 w-10 bg-gradient-to-r from-gray-950 to-transparent z-10 pointer-events-none" />
        <div className="absolute inset-y-0 right-0 w-10 bg-gradient-to-l from-gray-950 to-transparent z-10 pointer-events-none" />
        <div className="flex flex-col gap-4 pointer-events-none">
          <MarqueeRow phones={ROW_A} duration="26s" />
          <MarqueeRow phones={ROW_B} reverse duration="22s" />
        </div>
      </div>
    </section>
  );
}
