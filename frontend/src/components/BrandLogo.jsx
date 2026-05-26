/**
 * BrandLogo — the official MatchInMinutes wordmark.
 *
 * The lowercase "n" of the middle word "In" is replaced with a
 * heart-with-arrow glyph so the mark echoes the app icon in
 * /public/assets/icon.png. Reads as "MatchI[♡↗]Minutes".
 *
 * The heart sits at x-height (roughly 70% of cap height) so it fills
 * the footprint of a lowercase "n" rather than an uppercase letter.
 *
 * Variants:
 *   variant='full' (default) — icon badge + wordmark
 *   variant='wordmark'       — text only, with heart-M
 *   variant='mark'           — icon badge only
 *
 * Props:
 *   size   — 'sm' | 'md' | 'lg' | 'xl'     (default 'md')
 *   tone   — 'light' | 'dark'              (text colour; default 'light'
 *                                           = white for dark backgrounds)
 *   accent — tailwind text-* class for the heart-M and the M-span
 *            (default 'text-pink-500')
 *   className — extra classes on the outer span
 *
 * The icon badge renders /assets/icon.png inside a soft gradient ring.
 * If the image is missing it falls back to a Heart lucide icon so the
 * layout never collapses.
 */
import { useState } from "react";
import { Heart } from "lucide-react";

// Glyph sizes are tuned to lowercase x-height (~70% of the font's cap
// height) so the heart reads as an "n", not an "N".
const SIZE_MAP = {
  sm: { text: "text-base",  glyph: 11, badge: 28, badgePad: "p-1"    },
  md: { text: "text-lg",    glyph: 13, badge: 36, badgePad: "p-1.5"  },
  lg: { text: "text-2xl",   glyph: 17, badge: 44, badgePad: "p-2"    },
  xl: { text: "text-4xl",   glyph: 28, badge: 64, badgePad: "p-2.5"  },
};

/** The heart-n glyph: a plump heart with a cupid's-arrow piercing it
 *  diagonally, sized and vertically aligned to sit in a line of text
 *  exactly where a lowercase "n" would — baseline-aligned, x-height tall. */
function HeartNGlyph({ size = 13, className = "" }) {
  return (
    <svg
      viewBox="0 0 32 32"
      width={size}
      height={size}
      aria-hidden="true"
      focusable="false"
      className={`inline-block ${className}`}
      style={{ verticalAlign: "0em" }}
    >
      {/* Heart body */}
      <path
        d="M16 28.5
           C 16 28.5  3.5 20 3.5 11.8
           C 3.5 7.4  7 4  11.2 4
           C 13.4 4  15.2 5.2  16 6.8
           C 16.8 5.2  18.6 4  20.8 4
           C 25 4  28.5 7.4  28.5 11.8
           C 28.5 20  16 28.5  16 28.5 Z"
        fill="currentColor"
      />
      {/* Arrow shaft — diagonal through the heart */}
      <line
        x1="3" y1="25" x2="29" y2="3"
        stroke="currentColor"
        strokeWidth="2.4"
        strokeLinecap="round"
      />
      {/* Arrowhead (top-right) */}
      <path
        d="M29 3 L22.5 4.2 L27.8 9.5 Z"
        fill="currentColor"
      />
      {/* Feathers / fletching (bottom-left) */}
      <path
        d="M3 25 L7 21 L5.5 26.5 Z"
        fill="currentColor"
        opacity="0.85"
      />
      <path
        d="M3 25 L8.5 24 L5.5 27.5 Z"
        fill="currentColor"
        opacity="0.7"
      />
    </svg>
  );
}

/** The circular icon badge that renders the PNG app icon with a soft
 *  gradient halo. Falls back to a Heart lucide icon if the PNG 404s. */
function BrandMark({ size = 36, className = "" }) {
  const [imgOk, setImgOk] = useState(true);
  return (
    <span
      className={`relative inline-flex items-center justify-center flex-shrink-0 ${className}`}
      style={{ width: size, height: size }}
    >
      {/* Soft pink glow behind the icon */}
      <span className="absolute inset-0 rounded-full bg-pink-500/30 blur-md" />
      <span
        className="relative rounded-full bg-white flex items-center justify-center overflow-hidden"
        style={{
          width: size,
          height: size,
          boxShadow: "0 6px 18px -4px rgba(236,72,153,0.45), inset 0 1px 0 rgba(255,255,255,0.6)",
        }}
      >
        {imgOk ? (
          <img
            src="/assets/icon.png"
            alt=""
            className="w-[82%] h-[82%] object-contain"
            onError={() => setImgOk(false)}
          />
        ) : (
          <Heart size={size * 0.52} className="text-pink-500 fill-pink-500" />
        )}
      </span>
    </span>
  );
}

export default function BrandLogo({
  variant = "full",
  size = "md",
  tone = "light",
  accent = "text-pink-500",
  className = "",
}) {
  const s = SIZE_MAP[size] ?? SIZE_MAP.md;
  const textCls = tone === "dark" ? "text-gray-900" : "text-white";

  if (variant === "mark") {
    return <BrandMark size={s.badge} className={className} />;
  }

  const wordmark = (
    <span className={`inline-flex items-baseline font-extrabold tracking-tight ${s.text} ${textCls}`}>
      MatchI
      <span className={`${accent} inline-flex items-center`} aria-label="n">
        <HeartNGlyph size={s.glyph} />
      </span>
      <span className={accent}>Minutes</span>
    </span>
  );

  if (variant === "wordmark") {
    return <span className={className}>{wordmark}</span>;
  }

  // Full: badge + wordmark
  return (
    <span className={`inline-flex items-center gap-2.5 ${className}`}>
      <BrandMark size={s.badge} />
      {wordmark}
    </span>
  );
}

export { BrandMark, HeartNGlyph };
