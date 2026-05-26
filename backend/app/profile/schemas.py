from pydantic import BaseModel
from typing import Optional, List
from enum import Enum
from datetime import date


class Gender(str, Enum):
    male = "male"
    female = "female"
    non_binary = "non_binary"
    prefer_not_to_say = "prefer_not_to_say"


class RelationshipGoal(str, Enum):
    long_term = "long_term"
    short_term = "short_term"
    marriage = "marriage"
    serious_marriage = "serious_marriage"
    friendship = "friendship"
    casual = "casual"
    unsure = "unsure"


class EducationLevel(str, Enum):
    less_than_high_school = "less_than_high_school"
    high_school           = "high_school"
    some_college          = "some_college"
    associates            = "associates"
    diploma               = "diploma"            # vocational diploma / certificate
    trade_school          = "trade_school"
    bachelors             = "bachelors"
    postgraduate_diploma  = "postgraduate_diploma"
    masters               = "masters"
    professional          = "professional"       # MD, JD, MBA, CA, etc.
    phd                   = "phd"
    postdoc               = "postdoc"
    other                 = "other"


class RelationshipStatus(str, Enum):
    single = "single"
    divorced = "divorced"
    widowed = "widowed"
    separated = "separated"


# Tinder-style lifestyle chips — simple string enums keep frontend/backend in lockstep.
class Drinking(str, Enum):
    never = "never"
    rarely = "rarely"
    socially = "socially"
    often = "often"
    prefer_not_to_say = "prefer_not_to_say"


class Smoking(str, Enum):
    never = "never"
    socially = "socially"
    regularly = "regularly"
    trying_to_quit = "trying_to_quit"
    prefer_not_to_say = "prefer_not_to_say"


class Workout(str, Enum):
    never = "never"
    sometimes = "sometimes"
    regularly = "regularly"
    daily = "daily"


class Pets(str, Enum):
    dog = "dog"
    cat = "cat"
    both = "both"
    other = "other"
    none = "none"
    want_one = "want_one"


class Children(str, Enum):
    have_and_want_more = "have_and_want_more"
    have_and_dont_want_more = "have_and_dont_want_more"
    want = "want"
    dont_want = "dont_want"
    unsure = "unsure"


class Diet(str, Enum):
    vegetarian = "vegetarian"
    vegan = "vegan"
    non_vegetarian = "non_vegetarian"
    eggetarian = "eggetarian"
    jain = "jain"
    other = "other"


class ProfileCreateRequest(BaseModel):
    name: str
    age: int
    gender: Gender
    preferred_gender: Gender
    city: str
    country: str
    relationship_goal: RelationshipGoal
    # Core extras
    date_of_birth: Optional[date] = None
    phone_number: Optional[str] = None
    education_level: Optional[EducationLevel] = None
    occupation: Optional[str] = None
    college_university: Optional[str] = None
    workplace: Optional[str] = None
    bio: Optional[str] = None
    hobbies: Optional[List[str]] = []
    vibes: Optional[List[str]] = []
    relationship_status: Optional[RelationshipStatus] = None
    # Tinder-style lifestyle
    drinking: Optional[Drinking] = None
    smoking: Optional[Smoking] = None
    workout: Optional[Workout] = None
    pets: Optional[Pets] = None
    children: Optional[Children] = None
    diet: Optional[Diet] = None
    religion: Optional[str] = None
    languages: Optional[List[str]] = []
    height_cm: Optional[int] = None
    first_date_idea: Optional[str] = None
    compatibility_answers: Optional[List[dict]] = None
    # Serious-marriage only fields
    caste: Optional[str] = None
    sub_caste: Optional[str] = None
    sub_religion: Optional[str] = None
    annual_income: Optional[str] = None


class ProfileUpdateRequest(BaseModel):
    name: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[Gender] = None
    preferred_gender: Optional[Gender] = None
    phone_number: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None
    relationship_goal: Optional[RelationshipGoal] = None
    date_of_birth: Optional[date] = None
    education_level: Optional[EducationLevel] = None
    occupation: Optional[str] = None
    college_university: Optional[str] = None
    workplace: Optional[str] = None
    bio: Optional[str] = None
    hobbies: Optional[List[str]] = None
    vibes: Optional[List[str]] = None
    relationship_status: Optional[RelationshipStatus] = None
    drinking: Optional[Drinking] = None
    smoking: Optional[Smoking] = None
    workout: Optional[Workout] = None
    pets: Optional[Pets] = None
    children: Optional[Children] = None
    diet: Optional[Diet] = None
    religion: Optional[str] = None
    languages: Optional[List[str]] = None
    height_cm: Optional[int] = None
    first_date_idea: Optional[str] = None
    compatibility_answers: Optional[List[dict]] = None
    caste: Optional[str] = None
    sub_caste: Optional[str] = None
    sub_religion: Optional[str] = None
    annual_income: Optional[str] = None


class PartnerPreferencesRequest(BaseModel):
    preferred_gender: Optional[str] = None
    min_age: Optional[int] = None
    max_age: Optional[int] = None
    preferred_religion: Optional[str] = None
    preferred_relationship_goal: Optional[str] = None
    preferred_education: Optional[str] = None
    preferred_city: Optional[str] = None
    preferred_country: Optional[str] = None


class ProfileResponse(BaseModel):
    id: str
    name: str
    age: int
    gender: str
    preferred_gender: str
    city: str
    country: str
    relationship_goal: str
    date_of_birth: Optional[date] = None
    zodiac_sign: Optional[str] = None
    phone_number: Optional[str] = None
    education_level: Optional[str] = None
    occupation: Optional[str] = None
    college_university: Optional[str] = None
    workplace: Optional[str] = None
    bio: Optional[str] = None
    hobbies: List[str] = []
    vibes: List[str] = []
    relationship_status: Optional[str] = None
    drinking: Optional[str] = None
    smoking: Optional[str] = None
    workout: Optional[str] = None
    pets: Optional[str] = None
    children: Optional[str] = None
    diet: Optional[str] = None
    religion: Optional[str] = None
    languages: List[str] = []
    height_cm: Optional[int] = None
    first_date_idea: Optional[str] = None
    main_image_url: Optional[str] = None
    cover_image_url: Optional[str] = None
    verification_image_url: Optional[str] = None
    is_verified: bool = False
    # Fine-grained state so the frontend can distinguish "never uploaded"
    # (show upload banner), "pending admin review" (hide banner, treat as
    # partially verified with full access), and "rejected" (show rejected
    # banner + reupload CTA). `is_verified=true` iff status=='approved'.
    verification_status: Optional[str] = None  # 'none' | 'pending' | 'approved' | 'rejected'
    verification_note: Optional[str] = None    # admin-provided reject reason
    images: List[dict] = []
    compatibility_answers: List[dict] = []
    is_complete: bool = False
    caste: Optional[str] = None
    sub_caste: Optional[str] = None
    sub_religion: Optional[str] = None
    annual_income: Optional[str] = None
