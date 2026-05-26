// Shared styling primitives for the admin console. Keeps the tabs
// visually consistent without pulling in a component library.

export function Card({ className = "", children, ...rest }) {
  return (
    <div
      className={`rounded-xl border border-slate-800 bg-slate-900/50 ${className}`}
      {...rest}
    >
      {children}
    </div>
  );
}

export function SectionHeader({ title, description, actions }) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-3 mb-5">
      <div>
        <h2 className="text-xl font-semibold tracking-tight text-white">
          {title}
        </h2>
        {description ? (
          <p className="text-sm text-slate-400 mt-1 max-w-2xl">{description}</p>
        ) : null}
      </div>
      {actions ? <div className="flex items-center gap-2">{actions}</div> : null}
    </div>
  );
}

export function Pill({ tone = "slate", children }) {
  const tones = {
    slate:  "bg-slate-800 text-slate-300 border-slate-700",
    pink:   "bg-pink-600/20 text-pink-200 border-pink-500/30",
    green:  "bg-emerald-600/15 text-emerald-300 border-emerald-600/30",
    red:    "bg-red-600/15 text-red-300 border-red-600/30",
    amber:  "bg-amber-500/15 text-amber-200 border-amber-500/30",
    blue:   "bg-sky-500/15 text-sky-200 border-sky-500/30",
  };
  return (
    <span
      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] border ${tones[tone] || tones.slate}`}
    >
      {children}
    </span>
  );
}

export function Button({
  variant = "primary",
  size = "md",
  className = "",
  disabled,
  children,
  ...rest
}) {
  const base =
    "inline-flex items-center justify-center gap-1.5 font-medium rounded-lg transition-colors border";
  const sizes = {
    sm: "text-xs px-2.5 py-1.5",
    md: "text-sm px-3.5 py-2",
    lg: "text-sm px-4 py-2.5",
  };
  const variants = {
    primary: "bg-pink-600 border-pink-600 hover:bg-pink-500 text-white",
    secondary:
      "bg-slate-800 border-slate-700 hover:border-slate-600 text-slate-100",
    ghost:
      "bg-transparent border-transparent hover:bg-slate-800/60 text-slate-300",
    danger:
      "bg-red-600/90 border-red-600 hover:bg-red-500 text-white",
    success:
      "bg-emerald-600/90 border-emerald-600 hover:bg-emerald-500 text-white",
    outline:
      "bg-transparent border-slate-700 hover:border-slate-500 text-slate-200",
  };
  return (
    <button
      {...rest}
      disabled={disabled}
      className={`${base} ${sizes[size]} ${variants[variant]} ${
        disabled ? "opacity-50 cursor-not-allowed" : ""
      } ${className}`}
    >
      {children}
    </button>
  );
}

export function TextInput({ className = "", ...rest }) {
  return (
    <input
      {...rest}
      className={`rounded-lg bg-slate-950 border border-slate-800 focus:border-pink-500 focus:ring-1 focus:ring-pink-500/40 outline-none text-sm px-3 py-2 placeholder-slate-600 text-slate-100 ${className}`}
    />
  );
}

export function Select({ className = "", children, ...rest }) {
  return (
    <select
      {...rest}
      className={`rounded-lg bg-slate-950 border border-slate-800 focus:border-pink-500 focus:ring-1 focus:ring-pink-500/40 outline-none text-sm px-3 py-2 text-slate-100 ${className}`}
    >
      {children}
    </select>
  );
}

export function Empty({ title, description }) {
  return (
    <div className="p-10 text-center text-slate-400">
      <div className="text-sm font-medium text-slate-200">{title}</div>
      {description ? (
        <div className="text-xs mt-1 text-slate-500">{description}</div>
      ) : null}
    </div>
  );
}

export function formatINR(paiseOrRupees, { fromPaise = false } = {}) {
  const rupees = fromPaise ? Math.round(paiseOrRupees / 100) : paiseOrRupees;
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(rupees || 0);
}

export function formatDate(iso) {
  if (!iso) return "—";
  try {
    const d = new Date(iso);
    return d.toLocaleString("en-IN", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

export function formatDay(iso) {
  if (!iso) return "—";
  try {
    const d = new Date(iso);
    return d.toLocaleDateString("en-IN", {
      day: "2-digit",
      month: "short",
      year: "numeric",
    });
  } catch {
    return iso;
  }
}
