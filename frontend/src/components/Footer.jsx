import { Mail, MapPin, Phone } from "lucide-react";
import BrandLogo from "./BrandLogo";

const links = {
  Product: ["Features", "How It Works", "Pricing", "Success Stories"],
  Company: ["About Us", "Careers", "Blog", "Press Kit"],
  Support: ["Help Center", "Safety Tips", "Community", "Contact Us"],
  Legal: ["Privacy Policy", "Terms of Service", "Cookie Policy", "GDPR"],
};

const socials = [
  {
    label: "Facebook",
    svg: <svg viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4"><path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z" /></svg>,
  },
  {
    label: "Instagram",
    svg: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-4 h-4"><rect x="2" y="2" width="20" height="20" rx="5" /><circle cx="12" cy="12" r="4" /><circle cx="17.5" cy="6.5" r="0.5" fill="currentColor" /></svg>,
  },
  {
    label: "X",
    svg: <svg viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" /></svg>,
  },
  {
    label: "TikTok",
    svg: <svg viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4"><path d="M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-2.88 2.5 2.89 2.89 0 0 1-2.89-2.89 2.89 2.89 0 0 1 2.89-2.89c.28 0 .54.04.79.1V9.01a6.27 6.27 0 0 0-.79-.05 6.34 6.34 0 0 0-6.34 6.34 6.34 6.34 0 0 0 6.34 6.34 6.34 6.34 0 0 0 6.33-6.34V8.69a8.18 8.18 0 0 0 4.78 1.52V6.75a4.85 4.85 0 0 1-1.01-.06z" /></svg>,
  },
];

// Real, public contact surface — also used by the Contact nav link to
// smooth-scroll readers here. Phone/email are tap-to-action.
const contact = [
  { Icon: Mail,   text: "contact@matchinminutes.com", href: "mailto:contact@matchinminutes.com" },
  { Icon: Phone,  text: "+91 90947 70827",            href: "tel:919094770827" },
  { Icon: MapPin, text: "10, Gengu Road, Egmore, Chennai – 600 008", href: null },
];

export default function Footer() {
  return (
    <footer id="contact" className="bg-[#060612] border-t border-gray-800/50 scroll-mt-20">
      <div className="max-w-6xl mx-auto px-8 pt-16 pb-8">

        {/* Top grid */}
        <div className="grid grid-cols-2 md:grid-cols-7 gap-10 mb-14">

          {/* Brand col — wider */}
          <div className="col-span-2 md:col-span-3">
            <div className="mb-5">
              <BrandLogo variant="full" size="lg" tone="light" />
            </div>

            <p className="text-gray-500 text-sm leading-relaxed mb-6 max-w-xs">
              The dating website that helps you find real connections with people who share your world — one minute at a time.
            </p>

            {/* Contact */}
            <div className="flex flex-col gap-2.5 mb-6">
              {contact.map(({ Icon, text, href }) => {
                const Inner = (
                  <>
                    <div className="w-7 h-7 rounded-lg bg-[#13132a] border border-gray-800 flex items-center justify-center flex-shrink-0">
                      <Icon size={13} className="text-pink-400" />
                    </div>
                    <span className="leading-snug">{text}</span>
                  </>
                );
                return href ? (
                  <a key={text} href={href} className="flex items-center gap-2.5 text-gray-500 text-sm hover:text-pink-400 transition-colors">
                    {Inner}
                  </a>
                ) : (
                  <div key={text} className="flex items-center gap-2.5 text-gray-500 text-sm">{Inner}</div>
                );
              })}
            </div>

            {/* Socials */}
            <div className="flex gap-2.5">
              {socials.map((s) => (
                <a
                  key={s.label}
                  href="#"
                  aria-label={s.label}
                  className="w-9 h-9 rounded-xl bg-[#13132a] border border-gray-800 flex items-center justify-center text-gray-500 hover:text-pink-400 hover:border-pink-500/50 transition-all duration-200"
                >
                  {s.svg}
                </a>
              ))}
            </div>
          </div>

          {/* Link cols */}
          {Object.entries(links).map(([group, items]) => (
            <div key={group}>
              <h4 className="text-white font-semibold text-sm mb-4">{group}</h4>
              <ul className="flex flex-col gap-2.5">
                {items.map((item) => (
                  <li key={item}>
                    <a href="#" className="text-gray-500 text-sm hover:text-pink-400 transition-colors duration-200">
                      {item}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Newsletter */}
        <div className="bg-[#0f0f22] border border-gray-800/60 rounded-2xl p-6 mb-10 flex flex-col md:flex-row items-center justify-between gap-5">
          <div className="flex items-center gap-4">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-pink-600 to-purple-600 flex items-center justify-center flex-shrink-0" style={{ boxShadow: "0 6px 16px -4px rgba(236,72,153,0.4)" }}>
              <Mail size={18} className="text-white" />
            </div>
            <div>
              <p className="text-white font-semibold text-sm">Stay in the loop</p>
              <p className="text-gray-500 text-xs mt-0.5">Dating tips, success stories & updates to your inbox.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 w-full md:w-auto">
            <input
              type="email"
              placeholder="Enter your email"
              className="bg-[#0b0b18] border border-gray-800 text-gray-300 placeholder-gray-700 rounded-full px-5 py-2.5 text-sm outline-none focus:border-pink-500 w-full md:w-60 transition-colors"
            />
            <button className="bg-gradient-to-r from-pink-600 to-purple-600 text-white text-sm font-semibold px-6 py-2.5 rounded-full whitespace-nowrap hover:opacity-90 transition-opacity shadow-lg shadow-pink-600/20">
              Subscribe
            </button>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 pt-6 border-t border-gray-800/50">
          <p className="text-gray-600 text-xs">
            © 2025 MatchInMinutes. Crafted with care for people looking for love.
          </p>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
              <span className="text-gray-600 text-xs">All systems operational</span>
            </div>
            <span className="text-gray-700 text-xs">v2.1.0</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
