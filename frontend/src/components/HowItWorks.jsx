import { motion } from "framer-motion";
import { UserPlus, SlidersHorizontal, HeartHandshake } from "lucide-react";

const steps = [
  {
    Icon: UserPlus,
    title: "Create Your Profile",
    desc: "Sign up in seconds. Add your photos, bio, and interests to stand out to the right people.",
    gradient: "from-pink-600 to-rose-500",
    glow: "rgba(236,72,153,0.45)",
  },
  {
    Icon: SlidersHorizontal,
    title: "Discover Matches",
    desc: "Browse curated profiles nearby. Our smart filter shows people with common places and interests.",
    gradient: "from-purple-600 to-indigo-500",
    glow: "rgba(124,58,237,0.45)",
  },
  {
    Icon: HeartHandshake,
    title: "Connect & Date",
    desc: "Match, message, and plan your first date — all inside MatchInMinutes in just minutes.",
    gradient: "from-orange-500 to-pink-500",
    glow: "rgba(249,115,22,0.45)",
  },
];

const container = {
  hidden: {},
  show: { transition: { staggerChildren: 0.15 } },
};

const item = {
  hidden: { opacity: 0, y: 40 },
  show: { opacity: 1, y: 0, transition: { duration: 0.6 } },
};

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="bg-[#0b0b18] py-28 px-8 relative overflow-hidden scroll-mt-20">
      <div className="absolute inset-0 bg-gradient-to-b from-purple-900/5 to-transparent pointer-events-none" />

      <div className="max-w-6xl mx-auto relative z-10">
        {/* Heading */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="text-center mb-20"
        >
          <span className="inline-block bg-pink-500/10 border border-pink-500/30 text-pink-400 text-xs font-bold px-4 py-1.5 rounded-full mb-4 uppercase tracking-widest">
            Simple Steps
          </span>
          <h2 className="text-white text-4xl md:text-5xl font-extrabold">
            How{" "}
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-pink-500 to-purple-500">
              MatchInMinutes
            </span>{" "}
            Works
          </h2>
          <p className="text-gray-400 mt-4 max-w-xl mx-auto">
            Getting started is easy. You could be meeting your perfect match in less than 10 minutes.
          </p>
        </motion.div>

        {/* Steps */}
        <motion.div
          variants={container}
          initial="hidden"
          animate="show"
          className="grid grid-cols-1 md:grid-cols-3 gap-12 relative"
        >
          {/* Connector */}
          <div className="hidden md:block absolute top-14 left-[calc(16.67%+2rem)] right-[calc(16.67%+2rem)] h-px bg-gradient-to-r from-pink-500/0 via-pink-500/40 to-pink-500/0" />

          {steps.map((s, i) => (
            <motion.div
              key={s.title}
              variants={item}
              className="flex flex-col items-center text-center group"
            >
              {/* 3D Icon */}
              <div className="relative mb-8">
                <div className={`absolute inset-0 rounded-3xl bg-gradient-to-br ${s.gradient} opacity-25 blur-xl scale-110`} />
                <div
                  className={`relative w-28 h-28 rounded-3xl bg-gradient-to-br ${s.gradient} flex items-center justify-center group-hover:scale-105 transition-transform duration-300`}
                  style={{
                    boxShadow: `0 20px 40px -8px ${s.glow}, 0 8px 16px -4px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.2)`,
                    transform: "perspective(300px) rotateX(8deg) rotateY(-5deg)",
                  }}
                >
                  <s.Icon size={44} className="text-white" strokeWidth={1.5} />
                </div>
                <div className="absolute -top-3 -right-3 w-8 h-8 rounded-full bg-[#0b0b18] border-2 border-pink-500 flex items-center justify-center shadow-lg">
                  <span className="text-pink-400 text-xs font-black">{i + 1}</span>
                </div>
              </div>

              <h3 className="text-white font-bold text-xl mb-3">{s.title}</h3>
              <p className="text-gray-400 text-sm leading-relaxed max-w-xs">{s.desc}</p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
