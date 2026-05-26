import { motion } from "framer-motion";
import { ArrowRight, Search, Lock, UserPlus } from "lucide-react";
import { useNavigate } from "react-router-dom";

const badges = [
  { Icon: Lock, text: "Safe & Secure" },
  { Icon: UserPlus, text: "Verified Profiles" },
  { Icon: Search, text: "Free to Browse" },
];

export default function CTABanner() {
  const navigate = useNavigate();
  return (
    <section className="bg-[#0b0b18] py-24 px-8">
      <div className="max-w-4xl mx-auto text-center relative">
        <div className="absolute inset-0 bg-gradient-to-r from-pink-600/20 via-purple-600/20 to-indigo-600/20 rounded-3xl blur-3xl" />

        <motion.div
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0 }}
          transition={{ duration: 0.7 }}
          className="relative bg-gradient-to-br from-[#1a1a35] to-[#0f0f25] border border-pink-500/20 rounded-3xl p-14 shadow-2xl overflow-hidden"
        >
          <div className="absolute -top-20 -right-20 w-64 h-64 rounded-full bg-pink-600/10 blur-3xl" />
          <div className="absolute -bottom-20 -left-20 w-64 h-64 rounded-full bg-purple-600/10 blur-3xl" />

          {/* 3D Heart Icon */}
          <div className="flex justify-center mb-6">
            <div className="relative">
              <div className="absolute inset-0 rounded-2xl bg-gradient-to-br from-pink-600 to-purple-600 opacity-40 blur-xl scale-110" />
              <div
                className="relative w-20 h-20 rounded-2xl bg-gradient-to-br from-pink-600 to-purple-600 flex items-center justify-center"
                style={{ boxShadow: "0 16px 40px -8px rgba(236, 72, 153, 0.5), inset 0 1px 0 rgba(255,255,255,0.2)" }}
              >
                <svg viewBox="0 0 24 24" fill="white" className="w-10 h-10">
                  <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
                </svg>
              </div>
            </div>
          </div>

          <h2 className="text-white text-4xl md:text-5xl font-extrabold mb-4 relative z-10">
            Your Person Is{" "}
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-pink-500 to-purple-500">
              Waiting
            </span>
          </h2>
          <p className="text-gray-400 text-base max-w-xl mx-auto mb-10 relative z-10">
            Join over 8.6 million singles already finding meaningful connections on MatchInMinutes. It only takes a minute.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 relative z-10">
            <button onClick={() => navigate("/signup")}
              className="flex items-center gap-2 bg-gradient-to-r from-pink-600 to-purple-600 text-white font-bold px-10 py-4 rounded-full shadow-xl shadow-pink-600/30 hover:shadow-pink-600/50 hover:scale-105 transition-all duration-200 text-base">
              Join Free Today
              <ArrowRight size={18} />
            </button>
            <button onClick={() => navigate("/login")}
              className="flex items-center gap-2 bg-white/5 border border-gray-600 hover:border-pink-500 text-white font-semibold px-8 py-4 rounded-full transition-all duration-200 hover:bg-white/10 text-base">
              <Search size={16} className="text-pink-400" />
              Browse Profiles
            </button>
          </div>

          <div className="flex items-center justify-center gap-8 mt-10 flex-wrap relative z-10">
            {badges.map(({ Icon, text }) => (
              <span key={text} className="flex items-center gap-2 text-gray-500 text-xs">
                <div className="w-6 h-6 rounded-full bg-white/5 border border-gray-700 flex items-center justify-center">
                  <Icon size={12} className="text-pink-400" />
                </div>
                {text}
              </span>
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
