const floatingProfiles = [
  { name: "Emma", age: 24, common: 1, img: "https://randomuser.me/api/portraits/women/21.jpg", pos: "top-16 left-4" },
  { name: "George", age: 28, common: 4, img: "https://randomuser.me/api/portraits/men/45.jpg", pos: "bottom-24 left-8" },
  { name: "Christina", age: 24, common: 2, img: "https://randomuser.me/api/portraits/women/63.jpg", pos: "top-16 right-4" },
  { name: "Aaron", age: 32, common: 4, img: "https://randomuser.me/api/portraits/men/22.jpg", pos: "bottom-24 right-8" },
];

function FloatingCard({ name, age, common, img, pos }) {
  return (
    <div className={`absolute ${pos} flex items-center gap-3 bg-[#13132a] border border-gray-700/60 rounded-2xl px-4 py-3 shadow-xl shadow-black/40 backdrop-blur-sm z-10 w-48`}>
      <img src={img} alt={name} className="w-10 h-10 rounded-full object-cover flex-shrink-0 ring-2 ring-pink-500/40" />
      <div>
        <p className="text-white text-sm font-semibold">{name} <span className="text-gray-400 font-normal">{age}</span></p>
        <p className="text-orange-400 text-xs mt-0.5">{common} common places</p>
      </div>
    </div>
  );
}

export default function AppShowcase() {
  return (
    <section className="relative bg-[#0b0b18] py-24 px-8 overflow-hidden">
      {/* Glow blobs */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-purple-900/20 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute top-1/3 left-1/4 w-64 h-64 bg-pink-900/10 rounded-full blur-3xl pointer-events-none" />

      <div className="max-w-6xl mx-auto">
        {/* Heading */}
        <div className="text-center mb-16">
          <p className="text-pink-500 text-sm font-semibold tracking-widest uppercase mb-3">Find Your Match</p>
          <h2 className="text-white text-4xl md:text-5xl font-extrabold leading-tight">
            Discover People Around <br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-pink-500 to-purple-500">You Right Now</span>
          </h2>
          <p className="text-gray-400 mt-4 max-w-xl mx-auto text-base">
            Browse real profiles, see common interests, and connect instantly — all within minutes.
          </p>
        </div>

        {/* Phone + Floating cards */}
        <div className="relative flex justify-center items-center" style={{ minHeight: 580 }}>
          {/* Floating cards */}
          {floatingProfiles.map((p) => (
            <FloatingCard key={p.name} {...p} />
          ))}

          {/* Phone mockup */}
          <div className="relative w-64 bg-black rounded-[3rem] border-4 border-gray-700 shadow-2xl shadow-purple-900/40 overflow-hidden z-20">
            {/* Status bar */}
            <div className="flex items-center justify-between px-5 pt-4 pb-1">
              <span className="text-white text-xs font-medium">09:41</span>
              <div className="flex gap-1 items-center">
                <div className="w-3 h-3 bg-gray-600 rounded-sm" />
                <div className="w-3 h-3 bg-gray-600 rounded-full" />
              </div>
              <div className="flex gap-1 items-center">
                <span className="text-white text-xs">▲▲▲</span>
                <span className="text-white text-xs">■</span>
              </div>
            </div>

            {/* Profile image */}
            <div className="relative">
              <img
                src="https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400&q=80"
                alt="Jane"
                className="w-full h-96 object-cover object-top"
              />

              {/* Action buttons right side */}
              <div className="absolute right-3 bottom-24 flex flex-col gap-3">
                {["⚡", "📍", "⭐"].map((icon, i) => (
                  <div key={i} className="w-10 h-10 rounded-full bg-white/90 flex items-center justify-center text-base shadow-lg">
                    {icon}
                  </div>
                ))}
              </div>

              {/* Profile info overlay */}
              <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/90 via-black/50 to-transparent px-4 pt-10 pb-4">
                <div className="flex items-center gap-2">
                  <p className="text-white font-bold text-xl">Jane</p>
                  <span className="text-white font-bold text-xl">26</span>
                  <div className="w-5 h-5 bg-blue-500 rounded-full flex items-center justify-center">
                    <span className="text-white text-xs">✓</span>
                  </div>
                </div>
                <p className="text-gray-300 text-xs mt-1">📍 8 kilometers away</p>
                <p className="text-gray-300 text-xs">💼 Marcom Specialist at Paris</p>
                <p className="text-gray-300 text-xs">🎓 Galatasaray University 2014</p>
                <p className="text-orange-400 text-xs mt-1 font-medium">2 common places</p>
              </div>
            </div>

            {/* Bottom nav */}
            <div className="flex items-center justify-around py-4 bg-black border-t border-gray-800">
              <span className="text-gray-400 text-xl">👤</span>
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center shadow-lg shadow-pink-600/40">
                <span className="text-white text-sm font-bold">M</span>
              </div>
              <span className="text-gray-400 text-xl">❤️</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
