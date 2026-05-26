from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests
from app.supabase_client import supabase_admin
from app.auth.utils import hash_password, verify_password, create_token
from app.auth.dependencies import get_current_user
from app.config import settings

router = APIRouter()


class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    name: str
    phone_number: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    id_token: str


@router.post("/signup", status_code=201)
async def signup(body: SignupRequest):
    if len(body.password) < 8:
        raise HTTPException(400, "Password must be at least 8 characters")

    # Check duplicate email
    exists = supabase_admin.table("users").select("id").eq("email", body.email.lower()).execute()
    if exists.data:
        raise HTTPException(400, "An account with this email already exists")

    # Create user (password hashed at code level)
    payload = {
        "name": body.name.strip(),
        "email": body.email.lower(),
        "phone_number": body.phone_number,
        "password_hash": hash_password(body.password),
        "is_active": True,
    }
    res = supabase_admin.table("users").insert(payload).execute()
    if not res.data:
        raise HTTPException(500, "Failed to create account, please try again")

    user = res.data[0]

    # Stub profile row so later photo uploads / match queries have a FK target.
    # Real fields land via POST /profile/complete which flips is_complete=true.
    try:
        supabase_admin.table("profiles").insert({
            "id": user["id"],
            "name": user["name"],
            "is_complete": False,
        }).execute()
    except Exception:
        pass

    token = create_token(user["id"], user["email"])

    return {
        "user_id": user["id"],
        "email": user["email"],
        "name": user["name"],
        "access_token": token,
        "refresh_token": token,   # stateless — same token; swap for refresh logic if needed
        "message": "Account created. Please complete your profile.",
    }


@router.post("/login")
async def login(body: LoginRequest):
    res = supabase_admin.table("users").select("*").eq("email", body.email.lower()).execute()
    if not res.data:
        raise HTTPException(401, "Invalid email or password")

    user = res.data[0]

    if not user.get("is_active", True):
        raise HTTPException(403, "Account is disabled. Contact support.")

    if not user.get("password_hash"):
        raise HTTPException(401, "This account was created with Google. Please sign in with Google, or set a password via your account settings.")

    if not verify_password(body.password, user["password_hash"]):
        raise HTTPException(401, "Invalid email or password")

    token = create_token(user["id"], user["email"])

    return {
        "access_token": token,
        "refresh_token": token,
        "user_id": user["id"],
        "email": user["email"],
        "name": user["name"],
    }


@router.post("/logout")
async def logout():
    # JWT is stateless — client deletes the token from storage
    return {"message": "Logged out successfully"}


class SetPasswordRequest(BaseModel):
    new_password: str


@router.post("/set-password")
async def set_password(body: SetPasswordRequest, user=Depends(get_current_user)):
    """Allow Google (or any) user to set / update a password so they can also
    sign in with email + password as an alternative to OAuth."""
    if len(body.new_password) < 8:
        raise HTTPException(400, "Password must be at least 8 characters")
    supabase_admin.table("users").update(
        {"password_hash": hash_password(body.new_password)}
    ).eq("id", user["id"]).execute()
    return {"message": "Password set successfully"}


@router.post("/google")
async def google_auth(body: GoogleAuthRequest):
    """Sign in or sign up with a Google ID token.

    Frontend obtains the `id_token` via Google Identity Services (GSI) and posts it here.
    We verify it against our configured GOOGLE_CLIENT_ID, then match/create a user.
    Returns the same shape as /auth/login plus `is_new_user` and the existing profile
    completion flag so the frontend can decide whether to route to /signup or /dashboard.
    """
    try:
        info = google_id_token.verify_oauth2_token(
            body.id_token, google_requests.Request(), settings.google_client_id
        )
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired Google token")

    google_id = info.get("sub")
    email = (info.get("email") or "").lower()
    name = info.get("name") or email.split("@")[0]
    picture = info.get("picture") or ""

    if not google_id or not email:
        raise HTTPException(status_code=400, detail="Google token missing required fields")

    # 1) Lookup by google_id
    res = supabase_admin.table("users").select("*").eq("google_id", google_id).execute()
    user = res.data[0] if res.data else None

    # 2) Fall back to email lookup — links Google to an existing email/password account
    if not user:
        res = supabase_admin.table("users").select("*").eq("email", email).execute()
        user = res.data[0] if res.data else None
        if user:
            try:
                supabase_admin.table("users").update({"google_id": google_id}).eq("id", user["id"]).execute()
            except Exception:
                # google_id column may not exist yet — surface the real migration error
                raise HTTPException(
                    status_code=500,
                    detail="Users table missing `google_id` column. Run: alter table users add column if not exists google_id text;",
                )

    is_new_user = False

    # 3) Create user + stub profile if nothing matched
    if not user:
        try:
            created = supabase_admin.table("users").insert({
                "name": name,
                "email": email,
                "google_id": google_id,
                "password_hash": None,
                "is_active": True,
            }).execute()
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=(
                    "Failed to create Google user. Ensure `users.google_id text` column exists and "
                    "`users.password_hash` allows null."
                ),
            ) from e
        if not created.data:
            raise HTTPException(500, "Failed to create account")
        user = created.data[0]
        is_new_user = True

        # Stub profile row so later photo uploads / match queries have a FK target
        try:
            supabase_admin.table("profiles").insert({
                "id": user["id"],
                "name": name,
                "main_image_url": picture or None,
                "is_complete": False,
            }).execute()
        except Exception:
            pass

    if not user.get("is_active", True):
        raise HTTPException(403, "Account is disabled. Contact support.")

    # Check existing profile completeness so frontend can route to /dashboard vs /signup
    prof_res = supabase_admin.table("profiles").select("is_complete").eq("id", user["id"]).execute()
    is_complete = bool(prof_res.data and prof_res.data[0].get("is_complete"))

    token = create_token(user["id"], user["email"])

    return {
        "access_token": token,
        "refresh_token": token,
        "user_id": user["id"],
        "email": user["email"],
        "name": user.get("name") or name,
        "is_new_user": is_new_user,
        "is_complete": is_complete,
    }
