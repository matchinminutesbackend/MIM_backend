import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Clock, Heart, Shield, Sparkles } from "lucide-react";
import { useAuth } from "../context/AuthContext";

export default function UnderReview() {
  const { user, profile, platformOpen, refreshProfile, refreshPlatform, logout } = useAuth();
  const navigate = useNavigate();

  // Poll every 30s — redirect only after a confirmed fetch returns true
  useEffect(() => {
    const check = async () => {
      await refreshPlatform();
      await refreshProfile();
    };
    const interval = setInterval(check, 30_000);
    return () => clearInterval(interval);
  }, []);

  // platformOpen starts null (unknown), then resolves to true/false.
  // Only redirect when it's confirmed true (not the null default).
  useEffect(() => {
    if (platformOpen === true) navigate("/dashboard", { replace: true });
  }, [platformOpen]);

  function handleLogout() {
    logout();
    navigate("/login", { replace: true });
  }

  const name = profile?.name?.split(" ")[0] || "there";

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-black flex flex-col items-center justify-center px-4 py-12">

      {/* Glow blobs */}
      <div className="fixed -top-40 -left-40 w-[500px] h-[500px] rounded-full bg-rose-500/15 blur-3xl pointer-events-none" />
      <div className="fixed bottom-0 right-0 w-[400px] h-[400px] rounded-full bg-violet-500/10 blur-3xl pointer-events-none" />

      <div className="relative z-10 w-full max-w-md text-center">

        {/* Icon */}
        <div className="flex justify-center mb-6">
          <div className="w-20 h-20 rounded-full bg-gradient-to-br from-pink-500/20 to-fuchsia-500/20 border border-pink-500/30 flex items-center justify-center">
            <Clock className="w-9 h-9 text-pink-400" />
          </div>
        </div>

        {/* Heading */}
        <h1 className="text-2xl sm:text-3xl font-bold text-white mb-3 tracking-tight">
          Hi {name}, we&apos;re reviewing your profile!
        </h1>
        <p className="text-gray-400 text-sm leading-relaxed mb-8 max-w-sm mx-auto">
          Our team checks every profile before you go live — usually within a few hours.
          You&apos;ll be able to start exploring once we&apos;re done.
        </p>

        {/* Status card */}
        <div className="bg-white/5 border border-white/10 rounded-2xl p-5 mb-8 text-left space-y-4">
          <Step
            icon={<Shield className="w-4 h-4 text-green-400" />}
            bg="bg-green-500/15"
            label="Profile created"
            done
          />
          <Step
            icon={<Heart className="w-4 h-4 text-pink-400" />}
            bg="bg-pink-500/15"
            label="Photos uploaded"
            done={!!(profile?.main_image_url)}
          />
          <Step
            icon={<Clock className="w-4 h-4 text-amber-400" />}
            bg="bg-amber-500/15"
            label="Under review by our team"
            active
          />
          <Step
            icon={<Sparkles className="w-4 h-4 text-fuchsia-400" />}
            bg="bg-fuchsia-500/15"
            label="Start exploring matches"
            locked
          />
        </div>

        {/* What to expect */}
        <p className="text-xs text-gray-600 mb-8">
          We review profiles to keep the community safe and genuine.
          No action needed on your end — sit tight!
        </p>

        <button
          onClick={handleLogout}
          className="text-sm text-gray-500 hover:text-gray-300 transition-colors underline underline-offset-2"
        >
          Sign out
        </button>
      </div>
    </div>
  );
}

function Step({ icon, bg, label, done = false, active = false, locked = false }) {
  return (
    <div className="flex items-center gap-3">
      <div className={`w-8 h-8 rounded-full ${bg} flex items-center justify-center flex-shrink-0 ${locked ? "opacity-30" : ""}`}>
        {icon}
      </div>
      <span className={`text-sm font-medium ${done ? "text-white" : active ? "text-amber-300" : "text-gray-600"}`}>
        {label}
      </span>
      {done && (
        <span className="ml-auto text-xs text-green-400 font-semibold">Done</span>
      )}
      {active && (
        <span className="ml-auto flex items-center gap-1 text-xs text-amber-400 font-semibold">
          <span className="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse" />
          In progress
        </span>
      )}
    </div>
  );
}
