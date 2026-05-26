# mheartm

MatchInMinutes — dating app with consumer web app (React + Vite) and admin
dashboard, FastAPI + Supabase backend, Razorpay payments, and telemetry-driven
admin drill-downs.

## Layout

- `frontend/` — React 19 + Vite + Tailwind. Consumer app + admin SPA at `/admin`.
- `backend/` — FastAPI + Supabase (Postgres) + JWT auth.
- `supabase_*.sql` — schema, migrations, seed files. Run in order.

## Quick start

```bash
# backend
cd backend
python -m venv .venv && source .venv/Scripts/activate
pip install -r requirements.txt
cp .env.example .env   # fill in SUPABASE_URL / SERVICE_ROLE / JWT_SECRET
python run.py

# frontend
cd frontend
npm install
npm run dev

# MIM_backend
