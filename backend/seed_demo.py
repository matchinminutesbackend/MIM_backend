"""
Seed demo Indian profiles (3 male + 3 female) and verify Supabase connection.

Run from the `backend` directory:
    python seed_demo.py

- Verifies Supabase connectivity before seeding.
- Idempotent: re-running skips users that already exist (by email).
- All demo users share the password `demo1234` (for local testing only).
"""

import sys
from app.supabase_client import supabase_admin
from app.auth.utils import hash_password


DEMO_PASSWORD = "demo1234"

# Per-user stock photo sets. Each list is (main, extra1, extra2) — all
# Unsplash portraits of South-Asian men/women so the demo cards look
# native to the target audience. These are hot-linked, not uploaded to
# our Supabase Storage bucket, so they cost us nothing and never expire.
DEMO_USERS = [
    # ── Males ────────────────────────────────────────────────────────
    {
        "email": "arjun.sharma@demo.in",
        "name": "Arjun Sharma",
        "phone_number": "+91-9810012001",
        "photos": [
            "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=80",
            "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=80",
            "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=800&q=80",
        ],
        "profile": {
            "age": 28, "gender": "male", "preferred_gender": "female",
            "city": "Bengaluru", "country": "India",
            "relationship_goal": "long_term",
            "education_level": "bachelors",
            "occupation": "Software Engineer",
            "bio": "Weekend trekker, weekday coder. Love filter coffee and good books.",
            "hobbies": ["trekking", "coding", "reading", "photography"],
            "vibes": ["adventurous", "thoughtful", "ambitious"],
            "relationship_status": "single",
        },
    },
    {
        "email": "rohan.iyer@demo.in",
        "name": "Rohan Iyer",
        "phone_number": "+91-9820012002",
        "photos": [
            "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=80",
            "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&q=80",
            "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&q=80",
        ],
        "profile": {
            "age": 30, "gender": "male", "preferred_gender": "female",
            "city": "Mumbai", "country": "India",
            "relationship_goal": "marriage",
            "education_level": "masters",
            "occupation": "Finance Analyst",
            "bio": "South Indian at heart, Bombay by choice. Cricket, chai, and Carnatic music.",
            "hobbies": ["cricket", "music", "cooking"],
            "vibes": ["family-oriented", "witty", "grounded"],
            "relationship_status": "single",
        },
    },
    {
        "email": "kabir.patel@demo.in",
        "name": "Kabir Patel",
        "phone_number": "+91-9830012003",
        "photos": [
            "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&q=80",
            "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=80",
            "https://images.unsplash.com/photo-1463453091185-61582044d556?w=800&q=80",
        ],
        "profile": {
            "age": 26, "gender": "male", "preferred_gender": "female",
            "city": "Pune", "country": "India",
            "relationship_goal": "long_term",
            "education_level": "bachelors",
            "occupation": "Startup Founder",
            "bio": "Building things that matter. Foodie, runner, and dog dad.",
            "hobbies": ["running", "startups", "cooking", "travel"],
            "vibes": ["ambitious", "fun", "curious"],
            "relationship_status": "single",
        },
    },

    # ── Females ──────────────────────────────────────────────────────
    {
        "email": "ananya.reddy@demo.in",
        "name": "Ananya Reddy",
        "phone_number": "+91-9920012012",
        "photos": [
            "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=800&q=80",
            "https://images.unsplash.com/photo-1548142813-c348350df52b?w=800&q=80",
            "https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=800&q=80",
        ],
        "profile": {
            "age": 28, "gender": "female", "preferred_gender": "male",
            "city": "Hyderabad", "country": "India",
            "relationship_goal": "marriage",
            "education_level": "phd",
            "occupation": "Research Scientist",
            "bio": "Biryani maximalist. I read papers on weekdays, poetry on weekends.",
            "hobbies": ["reading", "research", "travel", "poetry"],
            "vibes": ["intellectual", "kind", "witty"],
            "relationship_status": "single",
        },
    },
    {
        "email": "divya.kapoor@demo.in",
        "name": "Divya Kapoor",
        "phone_number": "+91-9930012013",
        "photos": [
            "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&q=80",
            "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=800&q=80",
            "https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=800&q=80",
        ],
        "profile": {
            "age": 25, "gender": "female", "preferred_gender": "male",
            "city": "Delhi", "country": "India",
            "relationship_goal": "long_term",
            "education_level": "bachelors",
            "occupation": "Marketing Manager",
            "bio": "Delhi girl with Himachali roots. Mountains > beaches. Always down for a road trip.",
            "hobbies": ["travel", "hiking", "photography", "music"],
            "vibes": ["adventurous", "bubbly", "loyal"],
            "relationship_status": "single",
        },
    },
]


def check_connection() -> None:
    print("* Checking Supabase connection...", end=" ", flush=True)
    try:
        supabase_admin.table("users").select("id").limit(1).execute()
        print("OK")
    except Exception as e:
        print("FAILED")
        print(f"\n  Could not reach Supabase. Verify .env and that the schema is applied.\n  Error: {e}")
        sys.exit(1)


def seed_user(row: dict) -> str:
    email = row["email"]
    existing = supabase_admin.table("users").select("id").eq("email", email).execute()
    if existing.data:
        user_id = existing.data[0]["id"]
        print(f"  . {email:<28} already exists  -> {user_id}")
        return user_id

    created = supabase_admin.table("users").insert({
        "email": email,
        "name": row["name"],
        "phone_number": row["phone_number"],
        "password_hash": hash_password(DEMO_PASSWORD),
        "is_active": True,
    }).execute()
    user_id = created.data[0]["id"]
    print(f"  + {email:<28} created         -> {user_id}")
    return user_id


def seed_profile(user_id: str, row: dict) -> None:
    photos = row.get("photos") or []
    # main_image_url lives on the profiles row itself — this is what every
    # card / header avatar reads from. Without it, the UI shows the grey
    # placeholder fallback.
    main_url = photos[0] if photos else None
    payload = {
        "id": user_id,
        "name": row["name"],
        "phone_number": row["phone_number"],
        "is_complete": True,
        "main_image_url": main_url,
        **row["profile"],
    }
    existing = supabase_admin.table("profiles").select("id").eq("id", user_id).execute()
    if existing.data:
        supabase_admin.table("profiles").update(payload).eq("id", user_id).execute()
    else:
        supabase_admin.table("profiles").insert(payload).execute()


def seed_images(user_id: str, row: dict) -> None:
    """Populate the profile_images gallery. The detail drawer reads from
    here, so without rows the photo strip on the profile page is empty.

    Idempotent: if the user already has any images we skip — we don't
    want to pile up duplicate rows on re-runs."""
    photos = row.get("photos") or []
    if not photos:
        return
    existing = (
        supabase_admin.table("profile_images")
        .select("id")
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    if existing.data:
        return
    rows = [
        {
            "user_id": user_id,
            "image_url": url,
            "is_main": idx == 0,
            "order_index": idx,
        }
        for idx, url in enumerate(photos)
    ]
    supabase_admin.table("profile_images").insert(rows).execute()


def main() -> None:
    print("\n=== MatchInMinutes demo seeder ===\n")
    check_connection()
    print("\n* Seeding demo Indian profiles (3 male, 3 female)...\n")
    for row in DEMO_USERS:
        uid = seed_user(row)
        seed_profile(uid, row)
        seed_images(uid, row)
    print(f"\n[OK] Done. All demo accounts use password: {DEMO_PASSWORD!r}")
    print("  Log in with any of the emails above to try the app.\n")


if __name__ == "__main__":
    main()
