import { useEffect, useState } from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import {
  LayoutDashboard,
  Users,
  ShieldCheck,
  Gift,
  CreditCard,
  Banknote,
  Settings,
  History,
  LogOut,
  Menu,
  X,
  Flag,
  Megaphone,
} from "lucide-react";
import { adminApi, clearAdminSession, getAdminToken } from "../api/adminClient";

/**
 * AdminShell — persistent chrome for every admin dashboard route.
 *
 * Gates the whole subtree behind a valid admin token (pings /admin/me
 * on mount). Renders a left sidebar with the six module tabs and an
 * <Outlet /> for the active page. Mobile collapses the sidebar behind
 * a toggle so the console is usable on a phone in a pinch.
 */
const NAV = [
  { to: "/admin",               label: "Overview",      icon: LayoutDashboard, end: true },
  { to: "/admin/users",         label: "Users",         icon: Users },
  { to: "/admin/verifications", label: "Verifications", icon: ShieldCheck },
  { to: "/admin/gifts",         label: "Gifts",         icon: Gift },
  { to: "/admin/plans",         label: "Plans",         icon: CreditCard },
  { to: "/admin/withdrawals",   label: "Withdrawals",   icon: Banknote },
  { to: "/admin/reports",        label: "Reports",        icon: Flag },
  { to: "/admin/advertisement",  label: "Advertisement",  icon: Megaphone },
  { to: "/admin/settings",       label: "Settings",       icon: Settings },
  { to: "/admin/audit",          label: "Audit Log",      icon: History },
];

export default function AdminShell() {
  const navigate = useNavigate();
  const [admin, setAdmin] = useState(null);
  const [loading, setLoading] = useState(true);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    if (!getAdminToken()) {
      navigate("/admin/login", { replace: true });
      return;
    }
    adminApi
      .me()
      .then((me) => setAdmin(me))
      .catch(() => {
        clearAdminSession();
        navigate("/admin/login", { replace: true });
      })
      .finally(() => setLoading(false));
  }, [navigate]);

  function handleLogout() {
    clearAdminSession();
    navigate("/admin/login", { replace: true });
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400 text-sm">
        Loading admin console…
      </div>
    );
  }

  if (!admin) return null;

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex">
      {/* Sidebar */}
      <aside
        className={`${
          menuOpen ? "translate-x-0" : "-translate-x-full"
        } lg:translate-x-0 fixed lg:static inset-y-0 left-0 z-30 w-64 bg-slate-900 border-r border-slate-800 flex flex-col transition-transform duration-200`}
      >
        <div className="h-16 flex items-center justify-between px-5 border-b border-slate-800">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-pink-600/20 border border-pink-500/30 flex items-center justify-center">
              <ShieldCheck className="w-4 h-4 text-pink-400" />
            </div>
            <div>
              <div className="text-sm font-semibold leading-tight">MatchInMinutes</div>
              <div className="text-[10px] uppercase tracking-widest text-slate-500">Admin</div>
            </div>
          </div>
          <button
            className="lg:hidden text-slate-400 hover:text-white"
            onClick={() => setMenuOpen(false)}
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto py-4 px-3 space-y-1">
          {NAV.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              onClick={() => setMenuOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors ${
                  isActive
                    ? "bg-pink-600/20 text-pink-200 border border-pink-500/20"
                    : "text-slate-400 hover:text-white hover:bg-slate-800/60 border border-transparent"
                }`
              }
            >
              <Icon className="w-4 h-4" />
              {label}
            </NavLink>
          ))}
        </nav>

        <div className="border-t border-slate-800 p-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-8 h-8 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center text-xs font-semibold">
              {(admin.name || admin.email || "?").slice(0, 1).toUpperCase()}
            </div>
            <div className="min-w-0">
              <div className="text-xs font-medium truncate">{admin.name || "Admin"}</div>
              <div className="text-[10px] text-slate-500 truncate">{admin.email}</div>
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="w-full flex items-center justify-center gap-2 px-3 py-2 text-xs rounded-lg border border-slate-800 hover:border-slate-700 text-slate-300 hover:text-white"
          >
            <LogOut className="w-3.5 h-3.5" />
            Sign out
          </button>
        </div>
      </aside>

      {/* Backdrop for mobile drawer */}
      {menuOpen && (
        <div
          className="lg:hidden fixed inset-0 bg-black/60 z-20"
          onClick={() => setMenuOpen(false)}
        />
      )}

      {/* Main */}
      <div className="flex-1 flex flex-col min-w-0">
        <header className="h-16 border-b border-slate-800 bg-slate-950/80 backdrop-blur-sm flex items-center justify-between px-5 lg:px-8 sticky top-0 z-10">
          <div className="flex items-center gap-3">
            <button
              className="lg:hidden text-slate-400 hover:text-white"
              onClick={() => setMenuOpen(true)}
            >
              <Menu className="w-5 h-5" />
            </button>
            <div>
              <div className="text-xs uppercase tracking-widest text-slate-500">
                Admin Console
              </div>
              <div className="text-sm font-medium text-white">
                Operations · {new Date().toLocaleDateString()}
              </div>
            </div>
          </div>
          <div className="text-[11px] text-slate-500 hidden sm:block">
            Signed in as <span className="text-slate-300">{admin.email}</span>
          </div>
        </header>

        <main className="flex-1 p-5 lg:p-8 overflow-x-hidden">
          <Outlet context={{ admin }} />
        </main>
      </div>
    </div>
  );
}
