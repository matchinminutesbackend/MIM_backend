"""Verify seeded demo data by reading profiles + users back."""
from app.supabase_client import supabase_admin

EMAILS = [
    "arjun.sharma@demo.in", "rohan.iyer@demo.in", "kabir.patel@demo.in",
    "priya.menon@demo.in", "ananya.reddy@demo.in", "divya.kapoor@demo.in",
]

users = supabase_admin.table("users").select("id, email, name, is_active").in_("email", EMAILS).execute()
ids = [u["id"] for u in (users.data or [])]
profiles = supabase_admin.table("profiles").select(
    "id, name, age, gender, preferred_gender, city, country, relationship_goal, "
    "education_level, occupation, hobbies, vibes, is_complete"
).in_("id", ids).execute()
by_id = {p["id"]: p for p in (profiles.data or [])}

print(f"\nUsers found: {len(users.data or [])}/6")
print(f"Profiles found: {len(profiles.data or [])}/6\n")

print(f"{'Name':<18} {'Gender':<7} {'Age':<4} {'City':<12} {'Goal':<12} {'Edu':<10} {'Complete'}")
print("-" * 80)
for u in sorted(users.data or [], key=lambda x: x["name"]):
    p = by_id.get(u["id"])
    if not p:
        print(f"{u['name']:<18} -- NO PROFILE --")
        continue
    print(f"{p['name']:<18} {p['gender']:<7} {p['age']:<4} {p['city']:<12} "
          f"{p['relationship_goal']:<12} {p['education_level'] or '-':<10} {p['is_complete']}")

bad = [p["name"] for p in (profiles.data or []) if not p["is_complete"]]
if bad:
    print("\n[!] Incomplete profiles:", bad)
else:
    print("\n[OK] All profiles complete and ready for discovery.")

males = [p for p in (profiles.data or []) if p["gender"] == "male"]
females = [p for p in (profiles.data or []) if p["gender"] == "female"]
print(f"    Males: {len(males)}, Females: {len(females)}")
