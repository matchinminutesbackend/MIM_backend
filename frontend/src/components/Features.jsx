import { motion } from "framer-motion";
import { Zap, MapPin, MessageCircle, Shield, Target, Calendar } from "lucide-react";

const features = [
  { Icon: Zap,           title: "Smart Matching",    desc: "Our algorithm finds your most compatible matches based on personality, interests, and real-world location.",          gradient: "from-pink-500 to-rose-500",      border: "hover:border-pink-200" },
  { Icon: MapPin,        title: "Nearby Discovery",  desc: "Find singles within your city or neighborhood. Real connections happen in real places.",                             gradient: "from-purple-500 to-indigo-500",  border: "hover:border-purple-200" },
  { Icon: MessageCircle, title: "Instant Messaging", desc: "Break the ice with smart conversation starters and chat in real-time with your matches.",                            gradient: "from-orange-400 to-pink-500",    border: "hover:border-orange-200" },
  { Icon: Shield,        title: "Safe & Private",    desc: "Your privacy matters. End-to-end encrypted messages and 100% verified profiles only.",                               gradient: "from-teal-500 to-cyan-400",      border: "hover:border-teal-200" },
  { Icon: Target,        title: "Common Interests",  desc: "See exactly how many places, hobbies, and interests you share before the first hello.",                              gradient: "from-yellow-400 to-orange-400",  border: "hover:border-yellow-200" },
  { Icon: Calendar,      title: "Date Planning",     desc: "From match to date — we suggest the perfect spots based on your shared interests.",                                  gradient: "from-pink-500 to-purple-500",    border: "hover:border-pink-200" },
];

const container = {
  hidden: {},
  show: { transition: { staggerChildren: 0.08 } },
};
const item = {
  hidden: { opacity: 0, y: 40 },
  show:   { opacity: 1, y: 0, transition: { duration: 0.5 } },
};

export default function Features() {
  return (
    <section id="features" className="bg-gray-50 py-28 px-8 scroll-mt-20">
      <div className="max-w-6xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="text-center mb-16"
        >
          <span className="inline-block bg-pink-100 text-pink-600 text-xs font-bold px-4 py-1.5 rounded-full mb-4 uppercase tracking-widest">
            Why Choose Us
          </span>
          <h2 className="text-gray-900 text-4xl md:text-5xl font-extrabold">
            Everything You Need to{" "}
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-pink-500 to-purple-500">
              Find Love
            </span>
          </h2>
          <p className="text-gray-500 mt-4 max-w-xl mx-auto text-base">
            MatchInMinutes is packed with features designed to help you find genuine connections faster than ever.
          </p>
        </motion.div>

        <motion.div
          variants={container}
          initial="hidden"
          animate="show"
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
        >
          {features.map((f) => (
            <motion.div
              key={f.title}
              variants={item}
              className={`group bg-white border border-gray-100 ${f.border} rounded-3xl p-7 hover:shadow-2xl hover:-translate-y-2 transition-all duration-300 cursor-pointer`}
            >
              {/* 3D icon */}
              <div className="relative mb-6 w-16 h-16">
                <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br ${f.gradient} opacity-20 blur-md translate-y-2 scale-90`} />
                <div
                  className={`relative w-16 h-16 rounded-2xl bg-gradient-to-br ${f.gradient} flex items-center justify-center group-hover:scale-110 transition-transform duration-300`}
                  style={{ boxShadow: "0 8px 24px -4px rgba(0,0,0,0.15), inset 0 1px 0 rgba(255,255,255,0.25)" }}
                >
                  <f.Icon size={28} className="text-white" strokeWidth={1.8} />
                </div>
              </div>

              <h3 className="text-gray-900 font-bold text-lg mb-2">{f.title}</h3>
              <p className="text-gray-500 text-sm leading-relaxed">{f.desc}</p>

              <div className={`mt-5 inline-flex items-center gap-1.5 text-xs font-semibold bg-gradient-to-r ${f.gradient} bg-clip-text text-transparent`}>
                Learn more
                <svg className="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M5 12h14M12 5l7 7-7 7" /></svg>
              </div>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
