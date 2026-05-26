const avatars = [
  "https://randomuser.me/api/portraits/women/44.jpg",
  "https://randomuser.me/api/portraits/men/32.jpg",
  "https://randomuser.me/api/portraits/women/68.jpg",
];

export default function StatCard() {
  return (
    <div className="bg-purple-700/80 backdrop-blur-md rounded-2xl p-4 w-56 shadow-xl shadow-purple-900/40">
      <p className="text-white text-3xl font-extrabold leading-none mb-3">8.6m</p>

      {/* Overlapping avatars */}
      <div className="flex items-center mb-2">
        {avatars.map((src, i) => (
          <img
            key={i}
            src={src}
            alt="user"
            className="w-8 h-8 rounded-full border-2 border-purple-700 object-cover"
            style={{ marginLeft: i === 0 ? 0 : "-10px" }}
          />
        ))}
      </div>

      <p className="text-purple-200 text-xs leading-relaxed">
        There are 8.6 million user in the world everyone is happy with our services.
      </p>
    </div>
  );
}
