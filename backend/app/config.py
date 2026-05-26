from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    jwt_secret: str = "change-this-secret-in-production"
    jwt_expire_days: int = 7
    allowed_origins: str = "http://localhost:5173"
    google_client_id: str = "610696728606-hjv0463opi1e5umn1nas2e3589ss9dqv.apps.googleusercontent.com"

    # Razorpay — leave blank in .env to enable mock mode (backend simulates
    # successful purchases so the UI can be exercised without live keys).
    # NEVER commit real values; fill backend/.env which is gitignored.
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""
    razorpay_mode: str = "live"  # "live" | "mock" — mock shortcircuits purchase verify for local dev

    @property
    def origins(self) -> List[str]:
        return [o.strip() for o in self.allowed_origins.split(",")]

    class Config:
        env_file = ".env"


settings = Settings()
