import { Menu, X } from "lucide-react";
import { useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import BrandLogo from "./BrandLogo";

/**
 * Nav link schema:
 *   - `to`     → react-router route (absolute or "/" for landing)
 *   - `scroll` → element id on the landing page to smooth-scroll to after
 *                navigating. Paired with `to: "/"`. The scroll fires
 *                automatically once the landing page mounts, via the
 *                location.hash handoff below.
 */
const NAV_LINKS = [
  { label: "Home",         to: "/",       scroll: null },
  { label: "Features",     to: "/",       scroll: "features" },
  { label: "How It Works", to: "/",       scroll: "how-it-works" },
  { label: "About",        to: "/about",  scroll: null },
  { label: "Contact",      to: "/",       scroll: "contact" },
];

export default function Navbar() {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();

  // Clicking a scroll-target link: if we're already on "/" just scroll
  // in place; otherwise navigate with a hash so LandingPage can pick it
  // up on mount and scroll once the target section exists in the DOM.
  function goTo(link) {
    setOpen(false);
    if (link.scroll) {
      if (location.pathname === "/") {
        const el = document.getElementById(link.scroll);
        if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
        else navigate(`/#${link.scroll}`);
      } else {
        navigate(`/#${link.scroll}`);
      }
      return;
    }
    navigate(link.to);
    // If we navigated to "/" without a scroll target, make sure we're at
    // the top so the hero shows fresh.
    if (link.to === "/") window.scrollTo({ top: 0, behavior: "smooth" });
  }

  // "Home" highlights when on "/", "About" when on "/about".
  function isActive(link) {
    if (link.to === "/about") return location.pathname === "/about";
    if (link.label === "Home") return location.pathname === "/" && !location.hash;
    return false;
  }

  return (
    <nav className="flex items-center justify-between px-8 py-5 relative z-20">
      {/* Logo */}
      <button onClick={() => goTo(NAV_LINKS[0])} className="flex">
        <BrandLogo variant="full" size="md" tone="light" />
      </button>

      {/* Nav Links — desktop */}
      <ul className="hidden md:flex items-center gap-7">
        {NAV_LINKS.map((link) => (
          <li key={link.label}>
            <button
              onClick={() => goTo(link)}
              className={`text-sm font-medium transition-colors duration-200 ${
                isActive(link) ? "text-white" : "text-gray-400 hover:text-white"
              }`}
            >
              {link.label}
            </button>
          </li>
        ))}
      </ul>

      {/* CTA Buttons */}
      <div className="hidden md:flex items-center gap-3">
        <button onClick={() => navigate("/login")}
          className="text-gray-300 hover:text-white text-sm font-medium transition-colors px-4 py-2">
          Sign In
        </button>
        <button onClick={() => navigate("/signup")}
          className="bg-gradient-to-r from-pink-600 to-purple-600 text-white text-sm font-bold px-6 py-2.5 rounded-full shadow-lg shadow-pink-600/25 hover:shadow-pink-600/40 hover:scale-105 transition-all duration-200">
          Join Free
        </button>
      </div>

      {/* Mobile menu toggle */}
      <button
        className="md:hidden text-gray-400 hover:text-white"
        onClick={() => setOpen(!open)}
        aria-label={open ? "Close menu" : "Open menu"}
      >
        {open ? <X size={22} /> : <Menu size={22} />}
      </button>

      {/* Mobile menu */}
      {open && (
        <div className="absolute top-full left-0 right-0 bg-[#0f0f25] border-t border-gray-800 px-8 py-6 flex flex-col gap-4 md:hidden z-30">
          {NAV_LINKS.map((link) => (
            <button
              key={link.label}
              onClick={() => goTo(link)}
              className="text-left text-gray-300 hover:text-white text-sm font-medium"
            >
              {link.label}
            </button>
          ))}
          <div className="flex gap-3 mt-2">
            <button onClick={() => { setOpen(false); navigate("/login"); }}
              className="text-gray-300 border border-gray-700 text-sm font-medium px-5 py-2 rounded-full">Sign In</button>
            <button onClick={() => { setOpen(false); navigate("/signup"); }}
              className="bg-gradient-to-r from-pink-600 to-purple-600 text-white text-sm font-bold px-6 py-2 rounded-full">Join Free</button>
          </div>
        </div>
      )}
    </nav>
  );
}
