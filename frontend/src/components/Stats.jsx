import { motion, animate } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import { Users, HeartHandshake, Globe, TrendingUp } from "lucide-react";

const stats = [
  { Icon: Users,          end: 24,  suffix: "K+", label: "Active Members",    decimals: 1 },
  { Icon: HeartHandshake, end: 94,   suffix: "%",  label: "Match Success Rate", decimals: 0 },
  { Icon: Globe,          end: 3,  suffix: "+",  label: "Countries",          decimals: 0 },
  { Icon: TrendingUp,     end: 1,    suffix: "K+", label: "Couples Formed",     decimals: 0 },
];

function AnimatedNumber({ end, suffix, decimals, trigger }) {
  const [display, setDisplay] = useState("0" + suffix);
  const ref = useRef(null);

  useEffect(() => {
    if (!trigger) return;
    const controls = animate(0, end, {
      duration: 2.2,
      ease: "easeOut",
      onUpdate: (v) => setDisplay(v.toFixed(decimals) + suffix),
    });
    return () => controls.stop();
  }, [trigger, end, suffix, decimals]);

  return <span>{display}</span>;
}

const container = {
  hidden: {},
  show: { transition: { staggerChildren: 0.12 } },
};
const item = {
  hidden: { opacity: 0, y: 30 },
  show:   { opacity: 1, y: 0, transition: { duration: 0.55 } },
};

export default function Stats() {
  const [triggered, setTriggered] = useState(false);
  const sectionRef = useRef(null);

  useEffect(() => {
    const el = sectionRef.current;
    if (!el) return;
    const obs = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) { setTriggered(true); obs.disconnect(); } },
      { threshold: 0 }
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, []);

  return (
    <section
      ref={sectionRef}
      className="relative py-20 px-8 overflow-hidden"
      style={{ background: "linear-gradient(135deg,#c2185b 0%,#7b1fa2 50%,#3949ab 100%)" }}
    >
      <div className="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-pink-300/30 to-transparent" />
      <div className="absolute bottom-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-purple-300/30 to-transparent" />

      <motion.div
        variants={container}
        initial="hidden"
        animate="show"
        className="max-w-6xl mx-auto relative z-10 grid grid-cols-2 md:grid-cols-4 gap-10"
      >
        {stats.map(({ Icon, end, suffix, label, decimals }) => (
          <motion.div key={label} variants={item} className="text-center group">
            {/* 3D icon */}
            <div className="flex justify-center mb-4">
              <div className="relative">
                <div className="absolute inset-0 rounded-2xl bg-white/20 blur-md scale-110" />
                <div
                  className="relative w-16 h-16 rounded-2xl bg-white/10 border border-white/20 flex items-center justify-center group-hover:scale-110 transition-transform duration-300"
                  style={{ boxShadow: "0 8px 24px rgba(0,0,0,0.2), inset 0 1px 0 rgba(255,255,255,0.2)" }}
                >
                  <Icon size={28} className="text-white" strokeWidth={1.6} />
                </div>
              </div>
            </div>

            <div className="text-white text-4xl font-extrabold tabular-nums">
              <AnimatedNumber end={end} suffix={suffix} decimals={decimals} trigger={triggered} />
            </div>
            <p className="text-pink-200 text-sm mt-2 font-medium">{label}</p>
          </motion.div>
        ))}
      </motion.div>
    </section>
  );
}
