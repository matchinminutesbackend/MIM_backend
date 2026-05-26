from datetime import date, datetime
from typing import Optional

from app.supabase_client import supabase_admin
from app.profile.schemas import ProfileCreateRequest, ProfileUpdateRequest, PartnerPreferencesRequest
from fastapi import HTTPException


# ── Zodiac ────────────────────────────────────────────────────────────────────
# Western tropical zodiac cut-offs. Edge dates get the sign that *starts* on
# that day (the standard convention). Returns the English name for storage.
_ZODIAC_CUSPS = [
    ((1, 20),  "Capricorn"),   # up to Jan 19
    ((2, 19),  "Aquarius"),    # Jan 20 – Feb 18
    ((3, 21),  "Pisces"),      # Feb 19 – Mar 20
    ((4, 20),  "Aries"),       # Mar 21 – Apr 19
    ((5, 21),  "Taurus"),      # Apr 20 – May 20
    ((6, 21),  "Gemini"),      # May 21 – Jun 20
    ((7, 23),  "Cancer"),      # Jun 21 – Jul 22
    ((8, 23),  "Leo"),         # Jul 23 – Aug 22
    ((9, 23),  "Virgo"),       # Aug 23 – Sep 22
    ((10, 23), "Libra"),       # Sep 23 – Oct 22
    ((11, 22), "Scorpio"),     # Oct 23 – Nov 21
    ((12, 22), "Sagittarius"), # Nov 22 – Dec 21
    ((13, 1),  "Capricorn"),   # Dec 22 onwards
]


def zodiac_for(dob: date | str | None) -> Optional[str]:
    if dob is None:
        return None
    if isinstance(dob, str):
        try:
            dob = datetime.fromisoformat(dob).date()
        except Exception:
            return None
    m, d = dob.month, dob.day
    for (cm, cd), sign in _ZODIAC_CUSPS:
        if (m, d) < (cm, cd):
            return sign
    return "Capricorn"


def _age_from_dob(dob: date | str | None) -> Optional[int]:
    if dob is None:
        return None
    if isinstance(dob, str):
        try:
            dob = datetime.fromisoformat(dob).date()
        except Exception:
            return None
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def save_fcm_token(user_id: str, token: str) -> None:
    """Persist the device FCM push token against the user's profile.

    We store it in the profiles table (fcm_token column). The backend's FCM
    sender reads it from there when dispatching out-of-app notifications.
    Never raises — token registration is best-effort.
    """
    try:
        supabase_admin.table("profiles").update(
            {"fcm_token": token}
        ).eq("user_id", user_id).execute()
    except Exception:
        pass


def _enrich_payload(payload: dict) -> dict:
    """Derive zodiac_sign from date_of_birth and, when DOB is present, sync
    `age` so the two fields can't drift."""
    dob = payload.get("date_of_birth")
    if dob:
        # Supabase JSON-serialises date → string, so normalise before storing
        if isinstance(dob, date):
            payload["date_of_birth"] = dob.isoformat()
        zodiac = zodiac_for(dob)
        if zodiac:
            payload["zodiac_sign"] = zodiac
        derived_age = _age_from_dob(dob)
        if derived_age is not None:
            payload["age"] = derived_age
    return payload


# ── CRUD ──────────────────────────────────────────────────────────────────────
def get_profile(user_id: str) -> dict:
    res = supabase_admin.table("profiles").select("*, profile_images(*)").eq("id", user_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    profile = res.data
    profile["images"] = profile.pop("profile_images", [])
    return profile


def create_or_update_profile(user_id: str, data: ProfileCreateRequest) -> dict:
    payload = data.model_dump(exclude_none=True, mode="json")
    payload = _enrich_payload(payload)
    payload["id"] = user_id
    payload["is_complete"] = True

    existing = supabase_admin.table("profiles").select("id").eq("id", user_id).execute()

    if existing.data:
        res = supabase_admin.table("profiles").update(payload).eq("id", user_id).execute()
    else:
        res = supabase_admin.table("profiles").insert(payload).execute()

    if not res.data:
        raise HTTPException(status_code=500, detail="Failed to save profile")
    return res.data[0]


def update_profile(user_id: str, data: ProfileUpdateRequest) -> dict:
    payload = data.model_dump(exclude_none=True, mode="json")
    if not payload:
        raise HTTPException(status_code=400, detail="No fields to update")

    payload = _enrich_payload(payload)

    res = supabase_admin.table("profiles").update(payload).eq("id", user_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return res.data[0]


_GENDER_MAP = {
    "male": "male", "Male": "male",
    "female": "female", "Female": "female",
    "non-binary": "non_binary", "Non-binary": "non_binary", "non_binary": "non_binary",
    "prefer not to say": "prefer_not_to_say",
}

_PREF_FIELDS = "min_age,max_age,preferred_gender,preferred_religion,preferred_relationship_goal,preferred_education,preferred_city,preferred_country"

def get_partner_preferences(user_id: str) -> dict:
    res = supabase_admin.table("profiles").select(_PREF_FIELDS).eq("id", user_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return {k: v for k, v in res.data.items() if v is not None}


def update_partner_preferences_raw(user_id: str, data: dict) -> dict:
    allowed = {"min_age", "max_age", "preferred_gender", "preferred_religion",
               "preferred_relationship_goal", "preferred_education", "preferred_city", "preferred_country"}
    payload = {k: v for k, v in data.items() if k in allowed and v is not None}
    if not payload:
        raise HTTPException(status_code=400, detail="No fields to update")
    if "preferred_gender" in payload:
        payload["preferred_gender"] = _GENDER_MAP.get(payload["preferred_gender"], payload["preferred_gender"])
    res = supabase_admin.table("profiles").update(payload).eq("id", user_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return res.data[0]


def update_partner_preferences(user_id: str, data: PartnerPreferencesRequest) -> dict:
    payload = data.model_dump(exclude_none=True, mode="json")
    if not payload:
        raise HTTPException(status_code=400, detail="No fields to update")
    if "preferred_gender" in payload:
        payload["preferred_gender"] = _GENDER_MAP.get(payload["preferred_gender"], payload["preferred_gender"])
    res = supabase_admin.table("profiles").update(payload).eq("id", user_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return res.data[0]


def set_main_image(user_id: str, image_url: str):
    supabase_admin.table("profiles").update({"main_image_url": image_url}).eq("id", user_id).execute()


def get_public_profile(viewer_id: str, target_id: str) -> dict:
    if viewer_id == target_id:
        return get_profile(viewer_id)

    res = supabase_admin.table("profiles").select("*, profile_images(*)").eq("id", target_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    profile = res.data
    if not profile.get("is_complete"):
        raise HTTPException(status_code=404, detail="Profile not available")
    profile["images"] = profile.pop("profile_images", [])
    profile.pop("phone_number", None)
    return profile
