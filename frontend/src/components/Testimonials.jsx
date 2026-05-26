import { motion } from "framer-motion";
import { Star, Quote } from "lucide-react";

const reviews = [
  {
    name: "Sophie & James", since: "Together since 2024",
    text: "We matched on MatchInMinutes and discovered we visited the same coffee shop every Sunday without knowing. Our first date was there. Now we go together every week.",
    img1: "https://randomuser.me/api/portraits/women/33.jpg", img2: "https://randomuser.me/api/portraits/men/36.jpg",
    tag: "Couple Story", tagColor: "bg-pink-100 text-pink-600",
  },
  {
    name: "Priya M.", since: "Found her person",
    text: "I was skeptical about dating websites but MatchInMinutes felt different. The common places feature showed we both loved the same hiking trail. That was our first date.",
    img1: "https://randomuser.me/api/portraits/women/52.jpg", img2: null,
    tag: "Success Story", tagColor: "bg-purple-100 text-purple-600",
  },
  {
    name: "Marcus T.", since: "6 months strong",
    text: "Within 3 days of signing up I matched with someone who had 6 common places with me. We are now planning to move in together. This site changed my life.",
    img1: "https://randomuser.me/api/portraits/men/67.jpg", img2: null,
    tag: "Featured", tagColor: "bg-orange-100 text-orange-600",
  },
];

const container = {
  hidden: {},
  show: { transition: { staggerChildren: 0.15 } },
};
const item = {
  hidden: { opacity: 0, y: 50 },
  show:   { opacity: 1, y: 0, transition: { duration: 0.55 } },
};

export default function Testimonials() {
  return (
    <section className="bg-white py-28 px-8">
      <div className="max-w-6xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="text-center mb-16"
        >
          <span className="inline-block bg-pink-100 text-pink-600 text-xs font-bold px-4 py-1.5 rounded-full mb-4 uppercase tracking-widest">
            Love Stories
          </span>
          <h2 className="text-gray-900 text-4xl md:text-5xl font-extrabold">
            Real People,{" "}
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-pink-500 to-purple-500">
              Real Love
            </span>
          </h2>
          <p className="text-gray-500 mt-4 max-w-xl mx-auto">
            Thousands of couples found their match through MatchInMinutes. Here are a few of their stories.
          </p>
        </motion.div>

        <motion.div
          variants={container}
          initial="hidden"
          animate="show"
          className="grid grid-cols-1 md:grid-cols-3 gap-6"
        >
          {reviews.map((r) => (
            <motion.div
              key={r.name}
              variants={item}
              className="bg-white border border-gray-100 rounded-3xl p-7 shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all duration-300 relative overflow-hidden group"
            >
              <div className="absolute -top-4 -right-4 opacity-5 group-hover:opacity-10 transition-opacity">
                <Quote size={100} className="text-pink-500" />
              </div>

              <span className={`inline-block text-xs font-bold px-3 py-1 rounded-full mb-5 ${r.tagColor}`}>{r.tag}</span>

              <div className="flex gap-1 mb-4">
                {[...Array(5)].map((_, i) => <Star key={i} size={14} className="fill-yellow-400 text-yellow-400" />)}
              </div>

              <p className="text-gray-600 text-sm leading-relaxed mb-6">"{r.text}"</p>

              <div className="flex items-center gap-3 pt-4 border-t border-gray-100">
                <div className="flex">
                  <img src={r.img1} alt={r.name} className="w-11 h-11 rounded-full object-cover ring-2 ring-white shadow-md" />
                  {r.img2 && <img src={r.img2} alt="" className="w-11 h-11 rounded-full object-cover ring-2 ring-white shadow-md -ml-3" />}
                </div>
                <div>
                  <p className="text-gray-900 font-semibold text-sm">{r.name}</p>
                  <p className="text-pink-500 text-xs font-medium">{r.since}</p>
                </div>
              </div>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
