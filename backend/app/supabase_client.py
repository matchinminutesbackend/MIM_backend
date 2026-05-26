from supabase import create_client, Client
from app.config import settings

# Public client (anon key) — used for auth operations
supabase: Client = create_client(settings.supabase_url, settings.supabase_anon_key)

# Admin client (service role) — bypasses RLS for server-side operations
supabase_admin: Client = create_client(settings.supabase_url, settings.supabase_service_role_key)
