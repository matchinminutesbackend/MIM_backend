export default function PhoneMockup({ image, alt, heartColor = "orange", side = "left" }) {
  return (
    <div
      className={`relative flex-shrink-0 ${
        side === "left" ? "-mr-4 z-10" : "-ml-4 z-10"
      }`}
    >
      {/* Phone frame */}
      <div className="w-44 h-80 rounded-[2rem] border-4 border-gray-700 bg-black overflow-hidden shadow-2xl relative">
        {/* Notch */}
        <div className="absolute top-3 left-1/2 -translate-x-1/2 w-16 h-4 bg-black rounded-full z-10" />

        {/* Image */}
        <img
          src={image}
          alt={alt}
          className="w-full h-full object-cover"
        />

        {/* Heart icon */}
        <div
          className={`absolute top-6 ${
            side === "left" ? "right-3" : "left-3"
          } text-2xl drop-shadow-lg`}
        >
          {heartColor === "orange" ? "🧡" : "❤️"}
        </div>

        {/* Liked badge */}
        <div className="absolute bottom-4 left-1/2 -translate-x-1/2 bg-pink-600/90 backdrop-blur-sm text-white text-xs font-semibold px-4 py-1.5 rounded-full flex items-center gap-1.5 shadow-lg">
          <span>❤️</span> Liked
        </div>
      </div>
    </div>
  );
}
