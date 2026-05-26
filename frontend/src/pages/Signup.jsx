import { useState, useRef, useEffect, useCallback } from "react";
import { useNavigate, Link } from "react-router-dom";
import { useAuth, loadGoogleScript, GOOGLE_CLIENT_ID } from "../context/AuthContext";
import { api } from "../api/client";
import {
  User, Mail, Lock, Phone, Eye, EyeOff, MapPin, Briefcase,
  Camera, X, Star, ChevronRight, ChevronLeft, Check, ArrowRight,
  ShieldCheck, RefreshCw, Loader2, CropIcon,
} from "lucide-react";
import Cropper from "react-easy-crop";
import PhoneCollageBg from "../components/PhoneCollageBg";
import BrandLogo from "../components/BrandLogo";
import MultiSelectDropdown from "../components/MultiSelectDropdown";
import { COUNTRIES, INDIA_STATES, INDIA_STATE_NAMES } from "../data/locations";
import {
  MARRIAGE_RELIGIONS, SPECIAL_CASTE_OPTIONS,
  getCastesForState, getSubCastes, getSubReligions,
} from "../data/marriage_data";

const TOTAL_STEPS = 7;

const RELATIONSHIP_GOALS = [
  { value: "long_term",         label: "Long-term relationship", emoji: "💑" },
  { value: "short_term",        label: "Short-term / Casual",   emoji: "✨" },
  { value: "marriage",          label: "Marriage",              emoji: "💍" },
  { value: "serious_marriage",  label: "Serious Matrimony",     emoji: "🕌", badge: "New" },
  { value: "friendship",        label: "Friendship first",      emoji: "🤝" },
  { value: "casual",            label: "Just exploring",        emoji: "🌟" },
  { value: "unsure",            label: "Not sure yet",          emoji: "🤔" },
];

const GENDERS = [
  { value: "male", label: "Man" },
  { value: "female", label: "Woman" },
  { value: "non_binary", label: "Non-binary" },
  { value: "prefer_not_to_say", label: "Prefer not to say" },
];

const EDUCATION_LEVELS = [
  { value: "less_than_high_school", label: "Less than high school" },
  { value: "high_school",           label: "High school" },
  { value: "some_college",          label: "Some college" },
  { value: "associates",            label: "Associate degree" },
  { value: "diploma",               label: "Diploma / Certificate" },
  { value: "trade_school",          label: "Trade / Vocational school" },
  { value: "bachelors",             label: "Bachelor's degree" },
  { value: "postgraduate_diploma",  label: "Postgraduate diploma" },
  { value: "masters",               label: "Master's degree" },
  { value: "professional",          label: "Professional (MD / JD / MBA / CA)" },
  { value: "phd",                   label: "PhD / Doctorate" },
  { value: "postdoc",               label: "Postdoctoral" },
  { value: "other",                 label: "Other" },
];

// Broad list covering the world's major traditions + non-religious options.
// Free-form is preserved by the backend (stored as TEXT) so we allow custom
// entries via the "Other" option and a small input fallback when picked.
const RELIGION_OPTIONS = [
  "Agnostic",
  "Atheist",
  "Spiritual but not religious",
  "Buddhist",
  "Catholic",
  "Christian",
  "Eastern Orthodox",
  "Hindu",
  "Jain",
  "Jewish",
  "Muslim",
  "Parsi / Zoroastrian",
  "Protestant",
  "Shinto",
  "Sikh",
  "Taoist",
  "Wiccan / Pagan",
  "Other",
  "Prefer not to say",
];

const RELATIONSHIP_STATUSES = [
  { value: "single", label: "Single" },
  { value: "divorced", label: "Divorced" },
  { value: "widowed", label: "Widowed" },
  { value: "separated", label: "Separated" },
];

const LANGUAGE_OPTIONS = [
  { value: "English", label: "English" },
  { value: "Hindi", label: "Hindi" },
  { value: "Tamil", label: "Tamil" },
  { value: "Telugu", label: "Telugu" },
  { value: "Kannada", label: "Kannada" },
  { value: "Malayalam", label: "Malayalam" },
  { value: "Bengali", label: "Bengali" },
  { value: "Marathi", label: "Marathi" },
  { value: "Gujarati", label: "Gujarati" },
  { value: "Punjabi", label: "Punjabi" },
  { value: "Urdu", label: "Urdu" },
  { value: "Spanish", label: "Spanish" },
  { value: "French", label: "French" },
  { value: "German", label: "German" },
  { value: "Chinese", label: "Chinese" },
  { value: "Japanese", label: "Japanese" },
  { value: "Korean", label: "Korean" },
  { value: "Arabic", label: "Arabic" },
  { value: "Portuguese", label: "Portuguese" },
  { value: "Russian", label: "Russian" },
  { value: "Italian", label: "Italian" },
  { value: "Other", label: "Other" },
];

const HOBBY_OPTIONS = [
  { value: "travel", label: "Travel", emoji: "✈️" },
  { value: "music", label: "Music", emoji: "🎵" },
  { value: "movies", label: "Movies", emoji: "🎬" },
  { value: "reading", label: "Reading", emoji: "📚" },
  { value: "gaming", label: "Gaming", emoji: "🎮" },
  { value: "cooking", label: "Cooking", emoji: "🍳" },
  { value: "fitness", label: "Fitness", emoji: "💪" },
  { value: "yoga", label: "Yoga", emoji: "🧘‍♀️" },
  { value: "photography", label: "Photography", emoji: "📸" },
  { value: "dancing", label: "Dancing", emoji: "💃" },
  { value: "hiking", label: "Hiking", emoji: "🥾" },
  { value: "art", label: "Art", emoji: "🖼️" },
  { value: "coffee", label: "Coffee", emoji: "☕" },
  { value: "wine", label: "Wine", emoji: "🍷" },
  { value: "pets", label: "Pets", emoji: "🐶" },
  { value: "tech", label: "Tech", emoji: "💻" },
  { value: "fashion", label: "Fashion", emoji: "👗" },
  { value: "sports", label: "Sports", emoji: "⚽" },
  { value: "swimming", label: "Swimming", emoji: "🏊" },
  { value: "cycling", label: "Cycling", emoji: "🚴" },
  { value: "writing", label: "Writing", emoji: "✍️" },
  { value: "gardening", label: "Gardening", emoji: "🌱" },
];

const VIBE_OPTIONS = [
  { value: "adventurous", label: "Adventurous", emoji: "🌍" },
  { value: "romantic", label: "Romantic", emoji: "💖" },
  { value: "ambitious", label: "Ambitious", emoji: "🚀" },
  { value: "chill", label: "Chill", emoji: "🌿" },
  { value: "creative", label: "Creative", emoji: "🎨" },
  { value: "funny", label: "Funny", emoji: "😂" },
  { value: "intellectual", label: "Intellectual", emoji: "🧠" },
  { value: "spontaneous", label: "Spontaneous", emoji: "⚡" },
  { value: "spiritual", label: "Spiritual", emoji: "🕉️" },
  { value: "foodie", label: "Foodie", emoji: "🍜" },
  { value: "nightowl", label: "Night Owl", emoji: "🌙" },
  { value: "earlybird", label: "Early Bird", emoji: "🌅" },
  { value: "introvert", label: "Introvert", emoji: "🤫" },
  { value: "extrovert", label: "Extrovert", emoji: "🎉" },
  { value: "geeky", label: "Geeky", emoji: "🤓" },
  { value: "mindful", label: "Mindful", emoji: "🧘" },
];

// Lifestyle chips — values match backend enums in app/profile/schemas.py
const DRINKING_OPTIONS = [
  { value: "never",     label: "Never",      emoji: "🚫" },
  { value: "rarely",    label: "Rarely",     emoji: "🙂" },
  { value: "socially",  label: "Socially",   emoji: "🥂" },
  { value: "often",     label: "Often",      emoji: "🍸" },
  { value: "prefer_not_to_say", label: "Prefer not to say", emoji: "🤐" },
];
const SMOKING_OPTIONS = [
  { value: "never",          label: "Never",           emoji: "🚭" },
  { value: "socially",       label: "Socially",        emoji: "💨" },
  { value: "regularly",      label: "Regularly",       emoji: "🚬" },
  { value: "trying_to_quit", label: "Trying to quit",  emoji: "🤞" },
  { value: "prefer_not_to_say", label: "Prefer not to say", emoji: "🤐" },
];
const WORKOUT_OPTIONS = [
  { value: "never",      label: "Never",      emoji: "😌" },
  { value: "sometimes",  label: "Sometimes",  emoji: "🚶" },
  { value: "regularly",  label: "Regularly",  emoji: "💪" },
  { value: "daily",      label: "Daily",      emoji: "🏋️" },
];
const PETS_OPTIONS = [
  { value: "dog",      label: "Dog",       emoji: "🐶" },
  { value: "cat",      label: "Cat",       emoji: "🐱" },
  { value: "both",     label: "Both",      emoji: "🐾" },
  { value: "other",    label: "Other",     emoji: "🦜" },
  { value: "none",     label: "No pets",   emoji: "🙅" },
  { value: "want_one", label: "Want one",  emoji: "💖" },
];
const CHILDREN_OPTIONS = [
  { value: "have_and_want_more",      label: "Have & want more" },
  { value: "have_and_dont_want_more", label: "Have & don't want more" },
  { value: "want",                    label: "Want kids" },
  { value: "dont_want",               label: "Don't want kids" },
  { value: "unsure",                  label: "Not sure" },
];
const DIET_OPTIONS = [
  { value: "vegetarian",     label: "Vegetarian"     },
  { value: "vegan",          label: "Vegan"          },
  { value: "non_vegetarian", label: "Non-vegetarian" },
  { value: "eggetarian",     label: "Eggetarian"     },
  { value: "jain",           label: "Jain"           },
  { value: "other",          label: "Other"          },
];

function StepIndicator({ current }) {
  return (
    <div className="flex items-center gap-2 mb-8">
      {Array.from({ length: TOTAL_STEPS }).map((_, i) => (
        <div key={i} className={`h-1.5 rounded-full transition-all duration-300 ${
          i < current ? "flex-1 bg-pink-500" : i === current - 1 ? "flex-1 bg-pink-500" : "w-6 bg-gray-200"
        }`} />
      ))}
    </div>
  );
}

function TagButton({ label, selected, onClick }) {
  return (
    <button type="button" onClick={onClick}
      className={`px-3 py-1.5 rounded-full text-sm border transition-all ${
        selected ? "bg-pink-500 border-pink-500 text-white shadow-sm" : "bg-white border-gray-200 text-gray-600 hover:border-pink-400 hover:text-pink-500"
      }`}>
      {label}
    </button>
  );
}

function InputField({ icon, label, type = "text", placeholder, value, onChange, min, max, required, readOnly, hint }) {
  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-2">{label}</label>
      <div className="relative">
        {icon && <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400">{icon}</span>}
        <input
          type={type} value={value} onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder} min={min} max={max} required={required}
          readOnly={readOnly}
          aria-readonly={readOnly || undefined}
          tabIndex={readOnly ? -1 : undefined}
          className={`w-full border rounded-xl ${icon ? "pl-10" : "pl-4"} ${readOnly ? "pr-10 bg-gray-50 text-gray-500 border-gray-200 cursor-not-allowed select-all" : "pr-4 text-gray-900 border-gray-200 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent"} placeholder-gray-400 transition text-sm py-3`}
        />
        {readOnly && (
          /* Small lock icon at the right so it's immediately obvious why
             the field doesn't respond to clicks. Tooltip is the hint prop. */
          <span
            title={hint || "Not editable"}
            className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none"
            aria-hidden="true"
          >
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
              <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
            </svg>
          </span>
        )}
      </div>
      {hint && (
        <p className="mt-1.5 text-xs text-gray-400">{hint}</p>
      )}
    </div>
  );
}

function SelectButton({ label, selected, onClick }) {
  return (
    <button type="button" onClick={onClick}
      className={`py-2.5 px-3 rounded-xl border text-sm text-left transition-all ${
        selected ? "border-pink-500 bg-pink-50 text-pink-600 font-medium" : "border-gray-200 bg-white text-gray-600 hover:border-pink-300"
      }`}>
      {label}
    </button>
  );
}

// Cascading country → state → city picker. Only "India" has curated
// state+city data; other countries get free-text inputs for state and
// city so users outside India can still sign up. The stored fields are
// `country` and `city` — `state` is UI-only (not persisted) and exists
// purely to narrow the city dropdown for Indian addresses.
function LocationPicker({ country, state, city, onCountry, onState, onCity }) {
  const isIndia = country === "India";
  const isOtherCountry = country === "Other";
  const cityOptions = isIndia && state ? (INDIA_STATES[state] || []) : [];

  const selectClasses =
    "w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent transition text-sm bg-white";
  const inputClasses =
    "w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent transition text-sm";

  return (
    <div className="space-y-3">
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">Country</label>
        <select
          value={country}
          onChange={(e) => onCountry(e.target.value)}
          className={selectClasses}
        >
          {COUNTRIES.map((c) => (
            <option key={c} value={c}>{c}</option>
          ))}
        </select>
      </div>

      {/* Other country — let user type country name */}
      {isOtherCountry && (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">Enter country</label>
          <input
            type="text"
            placeholder="Your country"
            onChange={(e) => onCountry(e.target.value)}
            className={inputClasses}
          />
        </div>
      )}

      {isIndia ? (
        <>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">State</label>
            <select
              value={state}
              onChange={(e) => onState(e.target.value)}
              className={selectClasses}
            >
              <option value="">Select state…</option>
              {INDIA_STATE_NAMES.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">City</label>
            <select
              value={city}
              onChange={(e) => onCity(e.target.value)}
              disabled={!state}
              className={`${selectClasses} ${!state ? "opacity-60 cursor-not-allowed" : ""}`}
            >
              <option value="">{state ? "Select city…" : "Select state first"}</option>
              {cityOptions.map((c) => (
                <option key={c} value={c}>{c}</option>
              ))}
              {/* Escape hatch so users from smaller towns aren't blocked */}
              <option value="__other__">Other (type below)</option>
            </select>
            {city === "__other__" && (
              <input
                type="text"
                placeholder="Your city"
                onChange={(e) => onCity(e.target.value)}
                className={`mt-2 ${inputClasses}`}
                autoFocus
              />
            )}
          </div>
        </>
      ) : (
        // Non-India: free-text city. No state dropdown since we don't have
        // curated city data for other countries.
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">City</label>
          <div className="relative">
            <MapPin className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
            <input
              type="text"
              value={city}
              onChange={(e) => onCity(e.target.value)}
              placeholder="Your city"
              className={`${inputClasses} pl-10`}
            />
          </div>
        </div>
      )}
    </div>
  );
}

export default function Signup() {
  const { user, profile, signup, googleSignIn, refreshProfile } = useAuth();
  const navigate = useNavigate();
  const fileRef = useRef();
  const googleBtnRef = useRef(null);
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [showPwd, setShowPwd] = useState(false);
  const [images, setImages] = useState([]);
  const [uploadingImages, setUploadingImages] = useState(false);
  // Crop modal state
  const [cropSrc, setCropSrc] = useState(null);
  const [cropOriginalFile, setCropOriginalFile] = useState(null);
  const [cropQueue, setCropQueue] = useState([]);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState(null);
  // Set to true after a successful Google sign-in. Locks the email field,
  // hides the password + Google button, and makes handleNext skip the
  // /auth/signup call (Google already created the account).
  const [fromGoogle, setFromGoogle] = useState(false);

  const [form, setForm] = useState({
    name: "", email: "", password: "", phone_number: "",
    // India is the primary market — default country avoids a extra click
    // for most users. `state` is UI-only (not sent to backend) and used to
    // narrow the city dropdown for Indian addresses.
    age: "", date_of_birth: "", gender: "", city: "", state: "", country: "India",
    preferred_gender: "", relationship_goal: "",
    education_level: "", occupation: "", college_university: "", workplace: "",
    hobbies: [], vibes: [], relationship_status: "", bio: "",
    // Lifestyle / Tinder-style detail chips
    drinking: "", smoking: "", workout: "",
    pets: "", children: "", diet: "",
    religion: "", languages: [], height_cm: "",
    first_date_idea: "",
    // Serious-marriage-only fields
    caste: "", sub_caste: "", sub_religion: "", annual_income: "",
  });

  function set(field, value) { setForm((f) => ({ ...f, [field]: value })); }

  // If user lands here already authenticated (e.g. incomplete profile from a
  // previous session), skip account-creation and prefill what we know.
  // We do NOT advance if fromGoogle is true — the Google callback needs the
  // user to stay on step 1 to confirm name, phone, etc.
  useEffect(() => {
    if (step !== 1 || !user) return;
    // fromGoogle is set in the same event loop tick that sets user, so we
    // use a microtask delay to let that state settle before deciding.
    const tid = setTimeout(() => {
      setForm((f) => ({
        ...f,
        email: f.email || user.email || "",
        name: f.name || profile?.name || "",
        password: f.password || `existing_${user.id || Math.random().toString(36).slice(2)}`,
      }));
      // Only auto-advance for returning logged-in users, not fresh Google sign-ins.
      setFromGoogle((fg) => {
        if (!fg) setStep(2);
        return fg;
      });
    }, 0);
    return () => clearTimeout(tid);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  // Render Google Sign-In button while on step 1
  useEffect(() => {
    if (step !== 1) return;
    let cancelled = false;
    loadGoogleScript()
      .then((google) => {
        if (cancelled || !googleBtnRef.current) return;
        google.accounts.id.initialize({
          client_id: GOOGLE_CLIENT_ID,
          callback: async (resp) => {
            setError("");
            setLoading(true);
            try {
              // ── Decode Google JWT client-side (no verification — display only) ──
              // This gives us the name IMMEDIATELY, before the API call, so the
              // name field is never empty regardless of async timing.
              let googleNameFromJwt = "";
              try {
                const jwtPayload = JSON.parse(atob(resp.credential.split(".")[1]));
                googleNameFromJwt =
                  jwtPayload.given_name ||
                  (jwtPayload.name ? jwtPayload.name.split(" ")[0] : "") ||
                  "";
              } catch (_) {}

              // Pre-fill name immediately from the JWT so the field is
              // never blank regardless of async timing.
              if (googleNameFromJwt) {
                setForm((f) => ({ ...f, name: googleNameFromJwt }));
              }

              // ⚠️ Set fromGoogle=true BEFORE calling googleSignIn so that
              // when setUser() fires inside it the useEffect([user]) sees the
              // flag and does NOT auto-advance to step 2.
              setFromGoogle(true);

              const result = await googleSignIn(resp.credential);
              // Fully-completed profiles go straight to the app.
              if (result.is_complete) {
                navigate("/dashboard");
                return;
              }
              // Stay on step 1 — user must confirm name, add phone number,
              // and optionally set a password before continuing.
              setForm((f) => ({
                ...f,
                email: result.email || f.email,
                // Server name → JWT name → already-set name (never blank)
                name: result.name || googleNameFromJwt || f.name,
                phone_number: result.phone_number || f.phone_number,
                // Clear any auto-generated placeholder — password is optional
                password: "",
              }));
            } catch (err) {
              setError(err.message || "Google sign-in failed");
            } finally {
              setLoading(false);
            }
          },
        });
        // Clear any previously-rendered button before re-rendering (StrictMode double-mount)
        googleBtnRef.current.innerHTML = "";
        google.accounts.id.renderButton(googleBtnRef.current, {
          theme: "outline",
          size: "large",
          width: googleBtnRef.current.offsetWidth || 360,
          text: "signup_with",
          shape: "rectangular",
        });
      })
      .catch(() => {
        // Non-fatal — user can still sign up with email/password
      });
    return () => { cancelled = true; };
  }, [step, googleSignIn, navigate]);

  function toggleArray(field, value) {
    setForm((f) => ({
      ...f,
      [field]: f[field].includes(value) ? f[field].filter((v) => v !== value) : [...f[field], value],
    }));
  }

  // Compute age (years) from a YYYY-MM-DD date-of-birth string.
  function ageFromDob(dob) {
    if (!dob) return null;
    const d = new Date(dob);
    if (Number.isNaN(d.getTime())) return null;
    const today = new Date();
    let a = today.getFullYear() - d.getFullYear();
    const m = today.getMonth() - d.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < d.getDate())) a--;
    return a;
  }

  // Western tropical zodiac — matches backend app/profile/service.py so the
  // preview the user sees during signup is identical to the stored value.
  function zodiacFromDob(dob) {
    if (!dob) return null;
    const d = new Date(dob);
    if (Number.isNaN(d.getTime())) return null;
    const m = d.getMonth() + 1, day = d.getDate();
    const cusps = [
      [[1, 20],  "Capricorn",   "♑"],
      [[2, 19],  "Aquarius",    "♒"],
      [[3, 21],  "Pisces",      "♓"],
      [[4, 20],  "Aries",       "♈"],
      [[5, 21],  "Taurus",      "♉"],
      [[6, 21],  "Gemini",      "♊"],
      [[7, 23],  "Cancer",      "♋"],
      [[8, 23],  "Leo",         "♌"],
      [[9, 23],  "Virgo",       "♍"],
      [[10, 23], "Libra",       "♎"],
      [[11, 22], "Scorpio",     "♏"],
      [[12, 22], "Sagittarius", "♐"],
    ];
    for (const [[cm, cd], sign, glyph] of cusps) {
      if (m < cm || (m === cm && day < cd)) return { sign, glyph };
    }
    return { sign: "Capricorn", glyph: "♑" };
  }

  // Max DOB for the <input type="date"> picker — 18 years ago today.
  const maxDob = (() => {
    const t = new Date();
    t.setFullYear(t.getFullYear() - 18);
    return t.toISOString().slice(0, 10);
  })();

  function validate() {
    if (step === 1) {
      // Google users skip step 1 entirely (auto-advanced to step 2)
      // so this validation only runs for normal email/password signup.
      if (!form.name.trim()) return "Full name is required";
      if (!form.email.trim()) return "Email is required";
      if (!form.phone_number.trim()) return "Phone number is required";
      if (form.password.length < 8) return "Password must be at least 8 characters";
    }
    if (step === 2) {
      // Google users fill name + phone here (they skipped step 1)
      if (fromGoogle) {
        if (!form.name.trim()) return "Full name is required";
        if (!form.phone_number.trim()) return "Phone number is required";
      }
      const age = ageFromDob(form.date_of_birth);
      if (!form.date_of_birth) return "Date of birth is required";
      if (age === null || age < 18) return "You must be 18 or older";
      if (age > 100) return "Please enter a valid date of birth";
      if (!form.gender) return "Please select your gender";
      if (!form.country.trim()) return "Country is required";
      if (form.country === "India" && !form.state.trim()) return "State is required";
      if (!form.city.trim()) return "City is required";
    }
    if (step === 3) {
      if (!form.preferred_gender) return "Please select who you want to date";
      if (!form.relationship_goal) return "Please select a relationship goal";
    }
    if (step === 6) {
      if (images.length < 1) return "Please upload at least 1 photo";
    }
    return null;
  }

  async function handleNext() {
    const err = validate();
    if (err) { setError(err); return; }
    setError("");

    if (step === 1) {
      // Google flow: account already exists (created on /auth/google).
      // Skip /auth/signup — it would 409 on the duplicate email.
      // If the user chose to set a password, save it now so they can
      // also sign in with email + password in the future.
      if (fromGoogle) {
        if (form.password && form.password.length >= 8) {
          setLoading(true);
          try {
            await api.auth.setPassword(form.password);
          } catch (e) {
            // Non-fatal — password save failed, but don't block onboarding
            console.warn("Failed to save password:", e.message);
          } finally {
            setLoading(false);
          }
        }
        setStep(2);
        return;
      }
      setLoading(true);
      try {
        await signup(form.email, form.password, form.name, form.phone_number);
        setStep(2);
      } catch (e) {
        setError(e.message);
      } finally {
        setLoading(false);
      }
      return;
    }

    // Step 5 now saves the full profile so photo upload (step 6) has a FK target.
    if (step === 5) {
      await handleSaveProfile();
      return;
    }

    if (step === 6) {
      await handleImageUpload();
      return;
    }

    // Step 7 (face verification) has its own button inside the component
    if (step === 7) return;

    setStep((s) => s + 1);
  }

  async function handleSaveProfile() {
    setLoading(true);
    setError("");
    try {
      // Derive age server-side too, but send a best-guess so the required int
      // field on ProfileCreateRequest is satisfied even if DOB parsing fails.
      const derivedAge = ageFromDob(form.date_of_birth);
      const payload = {
        name: form.name,
        age: derivedAge ?? (form.age ? parseInt(form.age) : undefined),
        gender: form.gender,
        preferred_gender: form.preferred_gender,
        city: form.city,
        country: form.country,
        relationship_goal: form.relationship_goal,
        date_of_birth: form.date_of_birth || undefined,
        phone_number: form.phone_number || undefined,
        education_level: form.education_level || undefined,
        occupation: form.occupation || undefined,
        college_university: form.college_university?.trim() || undefined,
        workplace: form.workplace?.trim() || undefined,
        bio: form.bio || undefined,
        hobbies: form.hobbies,
        vibes: form.vibes,
        relationship_status: form.relationship_status || undefined,
        // Lifestyle / Tinder-style details
        drinking: form.drinking || undefined,
        smoking: form.smoking || undefined,
        workout: form.workout || undefined,
        pets: form.pets || undefined,
        children: form.children || undefined,
        diet: form.diet || undefined,
        religion: form.religion?.trim() || undefined,
        languages: (form.languages && form.languages.length) ? form.languages : undefined,
        height_cm: form.height_cm ? parseInt(form.height_cm) : undefined,
        first_date_idea: form.first_date_idea?.trim() || undefined,
        // Serious-marriage fields (null-safe — only sent when filled)
        caste: form.caste?.trim() || undefined,
        sub_caste: form.sub_caste?.trim() || undefined,
        sub_religion: form.sub_religion?.trim() || undefined,
        annual_income: form.annual_income || undefined,
      };
      await api.profile.complete(payload);
      setStep(6);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  // ── Canvas-based crop helper ──────────────────────────────────────────────
  async function getCroppedBlob(imageSrc, pixels) {
    const img = await new Promise((resolve, reject) => {
      const i = new Image();
      i.addEventListener("load", () => resolve(i));
      i.addEventListener("error", reject);
      i.setAttribute("crossorigin", "anonymous");
      i.src = imageSrc;
    });
    const canvas = document.createElement("canvas");
    canvas.width = pixels.width;
    canvas.height = pixels.height;
    canvas.getContext("2d").drawImage(
      img, pixels.x, pixels.y, pixels.width, pixels.height,
      0, 0, pixels.width, pixels.height
    );
    return new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.92));
  }

  function openCropFor(file) {
    setCrop({ x: 0, y: 0 });
    setZoom(1);
    setCroppedAreaPixels(null);
    setCropOriginalFile(file);
    setCropSrc(URL.createObjectURL(file));
  }

  function handleCropCancel() {
    if (cropSrc) URL.revokeObjectURL(cropSrc);
    setCropSrc(null);
    setCropOriginalFile(null);
    setCropQueue([]);
  }

  async function handleCropConfirm() {
    if (!croppedAreaPixels || !cropSrc || !cropOriginalFile) return;
    try {
      const blob = await getCroppedBlob(cropSrc, croppedAreaPixels);
      const croppedFile = new File([blob], cropOriginalFile.name, { type: "image/jpeg" });
      const preview = URL.createObjectURL(croppedFile);
      URL.revokeObjectURL(cropSrc);
      setImages((prev) => [...prev, { file: croppedFile, preview, uploaded: false, uploading: false }]);

      // Process next queued file if any
      const remaining = 6 - images.length - 1;
      if (cropQueue.length > 0 && remaining > 0) {
        const [next, ...rest] = cropQueue;
        setCropQueue(rest);
        openCropFor(next);
      } else {
        setCropSrc(null);
        setCropOriginalFile(null);
        setCropQueue([]);
      }
    } catch (_) {
      handleCropCancel();
    }
  }

  async function handleImageUpload() {
    if (images.length === 0) { setError("Upload at least 1 photo"); return; }
    setUploadingImages(true);
    setError("");
    try {
      for (let i = 0; i < images.length; i++) {
        if (!images[i].uploaded) {
          setImages((prev) => prev.map((img, idx) => idx === i ? { ...img, uploading: true } : img));
          await api.images.upload(images[i].file, i === 0);
          setImages((prev) => prev.map((img, idx) => idx === i ? { ...img, uploading: false, uploaded: true } : img));
        }
      }
      setStep(7);
    } catch (e) {
      setError(e.message);
      setImages((prev) => prev.map((img) => ({ ...img, uploading: false })));
    } finally {
      setUploadingImages(false);
    }
  }

  async function handleVerificationFinish(blob) {
    setLoading(true);
    setError("");
    try {
      const file = new File([blob], "verification.jpg", { type: "image/jpeg" });
      await api.images.uploadVerification(file);
      await refreshProfile().catch(() => {});
      navigate("/dashboard");
    } catch (e) {
      setError(e.message || "Could not save verification");
    } finally {
      setLoading(false);
    }
  }

  function addImages(files) {
    const remaining = 6 - images.length;
    const newFiles = Array.from(files).slice(0, remaining);
    if (newFiles.length === 0) return;
    // Reset input so the same file can be picked again
    if (fileRef.current) fileRef.current.value = "";
    // Queue all but the first; open crop for the first immediately
    setCropQueue(newFiles.slice(1));
    openCropFor(newFiles[0]);
  }

  function removeImage(idx) { setImages((prev) => prev.filter((_, i) => i !== idx)); }

  const stepTitles = [
    "Create your account",
    "Tell us about yourself",
    "What are you looking for?",
    "Career & education",
    "Vibes & interests",
    "Your best photos",
    "Verify it's really you",
  ];

  const stepSubtitles = [
    "Join millions finding real connections",
    "Help us find your perfect match",
    "Be honest — it helps us match better",
    "Optional, but makes profiles stand out",
    "Show your personality",
    "Profiles with photos get 10× more views",
    "A quick selfie helps us keep fake profiles out",
  ];

  return (
    <div className="relative min-h-screen flex items-center justify-center px-4 py-12 overflow-hidden">
      {/* Decorative phone-collage backdrop — sits behind everything else,
          pointer-events none. Gives the signup page a lively "start
          something epic" vibe without requiring any real imagery. */}
      <PhoneCollageBg />

      <div className="relative z-10 w-full max-w-lg">
        {/* Logo — heart-M wordmark, white text for dark phone-collage bg */}
        <Link to="/" className="flex items-center justify-center mb-8 drop-shadow-md">
          <BrandLogo variant="full" size="lg" tone="light" />
        </Link>

        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8">
          <StepIndicator current={step} />

          <div className="mb-6">
            <h2 className="text-xl font-bold text-gray-900">
              {step === 2 && fromGoogle ? "Your details" : stepTitles[step - 1]}
            </h2>
            <p className="text-sm text-gray-400 mt-0.5">
              {step === 2 && fromGoogle
                ? `Step ${step} of ${TOTAL_STEPS} · Tell us a bit about yourself`
                : `Step ${step} of ${TOTAL_STEPS} · ${stepSubtitles[step - 1]}`}
            </p>
          </div>

          {error && (
            <div className="mb-5 flex items-start gap-2 p-3.5 bg-red-50 border border-red-200 rounded-xl text-red-600 text-sm">
              <span>⚠️</span> {error}
            </div>
          )}

          {/* STEP 1 — two completely different layouts depending on sign-up method */}
          {step === 1 && (
            fromGoogle ? (
              /* ── Google sign-up: account linked, collect phone + optional password ── */
              <div className="space-y-5">

                {/* Google account confirmed card */}
                <div className="flex items-center gap-3 p-4 rounded-2xl bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-100">
                  <div className="w-11 h-11 rounded-full bg-white border border-gray-200 shadow-sm flex items-center justify-center flex-shrink-0">
                    {/* Google G logo */}
                    <svg viewBox="0 0 24 24" className="w-5 h-5">
                      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                      <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                      <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                      <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
                    </svg>
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-gray-900">Google account verified</p>
                    <p className="text-xs text-gray-500 truncate">{form.email}</p>
                  </div>
                  <div className="w-6 h-6 rounded-full bg-green-100 flex items-center justify-center flex-shrink-0">
                    <Check size={13} className="text-green-600" />
                  </div>
                </div>

                {/* Name — pre-filled, editable */}
                <InputField
                  icon={<User size={16} />}
                  label="Your name"
                  placeholder="Your full name"
                  value={form.name}
                  onChange={(v) => set("name", v)}
                  required
                  hint="Pre-filled from Google — feel free to edit"
                />

                {/* Phone — required (Google doesn't share it) */}
                <InputField
                  icon={<Phone size={16} />}
                  label="Phone number"
                  type="tel"
                  placeholder="+91 98765 43210"
                  value={form.phone_number}
                  onChange={(v) => set("phone_number", v)}
                  required
                  hint="Required — Google doesn't share your phone number"
                />

                {/* Password — optional, enables email login as alternative */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Password{" "}
                    <span className="text-gray-400 font-normal text-xs">(optional)</span>
                  </label>
                  <div className="relative">
                    <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                    <input
                      type={showPwd ? "text" : "password"}
                      value={form.password}
                      onChange={(e) => set("password", e.target.value)}
                      placeholder="Set a password to also sign in with email"
                      className="w-full border border-gray-200 rounded-xl pl-10 pr-12 py-3 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent transition text-sm"
                    />
                    <button type="button" onClick={() => setShowPwd(!showPwd)}
                      className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                      {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                  <p className="mt-1.5 text-xs text-gray-400">
                    Skip this if you prefer to always sign in with Google
                  </p>
                </div>
              </div>
            ) : (
              /* ── Normal email / password sign-up ── */
              <div className="space-y-4">
                {/* Google sign-up button */}
                <div ref={googleBtnRef} className="w-full flex justify-center min-h-[44px]" />

                <div className="flex items-center gap-3">
                  <div className="flex-1 h-px bg-gray-200" />
                  <span className="text-[11px] text-gray-400 font-medium uppercase tracking-wide">or sign up with email</span>
                  <div className="flex-1 h-px bg-gray-200" />
                </div>

                <InputField
                  icon={<User size={16} />}
                  label="Full name"
                  placeholder="Your full name"
                  value={form.name}
                  onChange={(v) => set("name", v)}
                  required
                />

                <InputField
                  icon={<Mail size={16} />}
                  label="Email address"
                  type="email"
                  placeholder="you@example.com"
                  value={form.email}
                  onChange={(v) => set("email", v)}
                  required
                />

                <InputField
                  icon={<Phone size={16} />}
                  label="Phone number"
                  type="tel"
                  placeholder="+91 98765 43210"
                  value={form.phone_number}
                  onChange={(v) => set("phone_number", v)}
                  required
                />

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Password</label>
                  <div className="relative">
                    <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                    <input
                      type={showPwd ? "text" : "password"}
                      value={form.password}
                      onChange={(e) => set("password", e.target.value)}
                      placeholder="Min. 8 characters"
                      className="w-full border border-gray-200 rounded-xl pl-10 pr-12 py-3 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent transition text-sm"
                    />
                    <button type="button" onClick={() => setShowPwd(!showPwd)}
                      className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                      {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                  <p className="mt-1.5 text-xs text-gray-400">Must be at least 8 characters</p>
                </div>
              </div>
            )
          )}

          {/* STEP 2 — About you */}
          {step === 2 && (
            <div className="space-y-5">

              {/* Google users land here directly — collect name + phone first */}
              {fromGoogle && (
                <>
                  <div className="flex items-center gap-2.5 px-3 py-2.5 bg-blue-50 border border-blue-100 rounded-xl">
                    <svg viewBox="0 0 24 24" className="w-4 h-4 flex-shrink-0">
                      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                      <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                      <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                      <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
                    </svg>
                    <span className="text-xs text-blue-700 font-medium">Signed in with Google · {form.email}</span>
                  </div>

                  <InputField
                    icon={<User size={16} />}
                    label="Your name"
                    placeholder="Your full name"
                    value={form.name}
                    onChange={(v) => set("name", v)}
                    required
                    hint="Pre-filled from Google — feel free to edit"
                  />

                  <InputField
                    icon={<Phone size={16} />}
                    label="Phone number"
                    type="tel"
                    placeholder="+91 98765 43210"
                    value={form.phone_number}
                    onChange={(v) => set("phone_number", v)}
                    required
                    hint="Google doesn't share your phone number"
                  />

                  <div className="h-px bg-gray-100" />
                </>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Date of birth</label>
                <input
                  type="date"
                  value={form.date_of_birth}
                  max={maxDob}
                  onChange={(e) => set("date_of_birth", e.target.value)}
                  className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent transition text-sm"
                />
                {form.date_of_birth && ageFromDob(form.date_of_birth) !== null && (
                  <div className="mt-2 flex flex-wrap items-center gap-2 text-xs">
                    <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-pink-50 text-pink-600 font-medium">
                      🎂 {ageFromDob(form.date_of_birth)} years old
                    </span>
                    {zodiacFromDob(form.date_of_birth) && (
                      <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-purple-50 text-purple-600 font-medium">
                        {zodiacFromDob(form.date_of_birth).glyph} {zodiacFromDob(form.date_of_birth).sign}
                      </span>
                    )}
                  </div>
                )}
                <p className="mt-1.5 text-xs text-gray-400">You must be at least 18 to join MatchInMinutes.</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">I identify as…</label>
                <div className="grid grid-cols-2 gap-2">
                  {GENDERS.map((g) => (
                    <SelectButton key={g.value} label={g.label} selected={form.gender === g.value} onClick={() => set("gender", g.value)} />
                  ))}
                </div>
              </div>
              <LocationPicker
                country={form.country}
                state={form.state}
                city={form.city}
                onCountry={(v) => { set("country", v); set("state", ""); set("city", ""); }}
                onState={(v) => { set("state", v); set("city", ""); }}
                onCity={(v) => set("city", v)}
              />
            </div>
          )}

          {/* STEP 3 — Preferences */}
          {step === 3 && (
            <div className="space-y-5">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">I'm interested in…</label>
                <div className="grid grid-cols-2 gap-2">
                  {GENDERS.map((g) => (
                    <SelectButton key={g.value} label={g.label} selected={form.preferred_gender === g.value} onClick={() => set("preferred_gender", g.value)} />
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">What are you looking for?</label>
                <div className="grid grid-cols-2 gap-2">
                  {RELATIONSHIP_GOALS.map((g) => (
                    <button
                      key={g.value}
                      type="button"
                      onClick={() => { set("relationship_goal", g.value); set("caste", ""); set("sub_caste", ""); set("sub_religion", ""); }}
                      className={`relative py-2.5 px-3 rounded-xl border text-sm text-left transition-all ${
                        form.relationship_goal === g.value
                          ? g.value === "serious_marriage"
                            ? "border-purple-500 bg-purple-50 text-purple-700 font-medium"
                            : "border-pink-500 bg-pink-50 text-pink-600 font-medium"
                          : "border-gray-200 bg-white text-gray-600 hover:border-pink-300"
                      }`}
                    >
                      {g.emoji} {g.label}
                      {g.badge && (
                        <span className="absolute -top-2 -right-1 bg-purple-500 text-white text-[9px] px-1.5 py-0.5 rounded-full font-bold leading-tight">
                          {g.badge}
                        </span>
                      )}
                    </button>
                  ))}
                </div>
              </div>

              {/* Serious Marriage info banner */}
              {form.relationship_goal === "serious_marriage" && (
                <div className="p-3.5 bg-purple-50 border border-purple-200 rounded-xl text-sm text-purple-700 space-y-1">
                  <p className="font-semibold">🕌 Serious Matrimony pool</p>
                  <p className="text-xs text-purple-600 leading-relaxed">
                    You'll only see and be seen by others who are also seriously looking for marriage. Your caste, religion, and family details help us find compatible matches.
                  </p>
                </div>
              )}

              {/* Marriage-specific fields — shown only for serious_marriage */}
              {form.relationship_goal === "serious_marriage" && (
                <div className="space-y-4 pt-1 border-t border-purple-100">
                  <p className="text-xs text-gray-400">These details are only shared with other serious matrimony profiles.</p>

                  {/* Caste */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Caste</label>
                    <select
                      value={form.caste}
                      onChange={(e) => { set("caste", e.target.value); set("sub_caste", ""); }}
                      className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white text-sm"
                    >
                      <option value="">Select caste…</option>
                      {SPECIAL_CASTE_OPTIONS.map((c) => (
                        <option key={c} value={c}>{c}</option>
                      ))}
                      {form.state && getCastesForState(form.state).length > 0 && (
                        <optgroup label={`— ${form.state} communities —`}>
                          {getCastesForState(form.state).map((c) => (
                            <option key={c} value={c}>{c}</option>
                          ))}
                        </optgroup>
                      )}
                      {(!form.state || getCastesForState(form.state).length === 0) && (
                        <option value="Other">Other</option>
                      )}
                    </select>
                    {form.caste === "Other" && (
                      <input
                        type="text"
                        placeholder="Enter your caste"
                        onChange={(e) => set("caste", e.target.value)}
                        className="mt-2 w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
                      />
                    )}
                  </div>

                  {/* Sub-caste */}
                  {form.caste && !SPECIAL_CASTE_OPTIONS.includes(form.caste) && (
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Sub-caste</label>
                      <select
                        value={form.sub_caste}
                        onChange={(e) => set("sub_caste", e.target.value)}
                        className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white text-sm"
                      >
                        <option value="">Select…</option>
                        <option value="No Sub-caste">No Sub-caste</option>
                        <option value="Any Sub-caste">Any Sub-caste</option>
                        {getSubCastes(form.caste).map((s) => (
                          <option key={s} value={s}>{s}</option>
                        ))}
                        <option value="Other">Other</option>
                      </select>
                    </div>
                  )}

                  {/* Religion (marriage-specific dropdown with Indian focus) */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Religion</label>
                    <select
                      value={form.religion}
                      onChange={(e) => { set("religion", e.target.value); set("sub_religion", ""); }}
                      className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white text-sm"
                    >
                      <option value="">Select religion…</option>
                      {MARRIAGE_RELIGIONS.map((r) => (
                        <option key={r} value={r}>{r}</option>
                      ))}
                    </select>
                  </div>

                  {/* Sub-religion */}
                  {form.religion && form.religion !== "No Religion" && form.religion !== "Any Religion" && getSubReligions(form.religion).length > 0 && (
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Sub-religion / Sect</label>
                      <select
                        value={form.sub_religion}
                        onChange={(e) => set("sub_religion", e.target.value)}
                        className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white text-sm"
                      >
                        <option value="">Select…</option>
                        {getSubReligions(form.religion).map((s) => (
                          <option key={s} value={s}>{s}</option>
                        ))}
                      </select>
                    </div>
                  )}

                  {/* Annual Income */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      💼 Annual Income <span className="text-gray-400 font-normal">(optional)</span>
                    </label>
                    <select
                      value={form.annual_income}
                      onChange={(e) => set("annual_income", e.target.value)}
                      className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white text-sm"
                    >
                      <option value="">Select range…</option>
                      <option value="prefer_not_to_say">Prefer not to say</option>
                      <optgroup label="— Annual Income (INR) —">
                        <option value="below_2l">Below ₹2 Lakh</option>
                        <option value="2l_4l">₹2 – 4 Lakh</option>
                        <option value="4l_6l">₹4 – 6 Lakh</option>
                        <option value="6l_10l">₹6 – 10 Lakh</option>
                        <option value="10l_15l">₹10 – 15 Lakh</option>
                        <option value="15l_25l">₹15 – 25 Lakh</option>
                        <option value="25l_50l">₹25 – 50 Lakh</option>
                        <option value="50l_1cr">₹50 Lakh – 1 Crore</option>
                        <option value="above_1cr">Above ₹1 Crore</option>
                      </optgroup>
                    </select>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* STEP 4 — Career */}
          {step === 4 && (
            <div className="space-y-4">
              <p className="text-sm text-gray-400 -mt-2">All optional — helps us find better matches for you</p>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Education level</label>
                <div className="grid grid-cols-2 gap-2">
                  {EDUCATION_LEVELS.map((e) => (
                    <SelectButton key={e.value} label={e.label} selected={form.education_level === e.value} onClick={() => set("education_level", e.value)} />
                  ))}
                </div>
              </div>
                            <InputField icon={<Briefcase size={16} />} label="College / University (optional)" placeholder="e.g. Stanford University" value={form.college_university} onChange={(v) => set("college_university", v)} />
              <InputField icon={<Briefcase size={16} />} label="Workplace (optional)" placeholder="e.g. Google, Self-employed" value={form.workplace} onChange={(v) => set("workplace", v)} />
              <InputField icon={<Briefcase size={16} />} label="Occupation" placeholder="e.g. Software Engineer" value={form.occupation} onChange={(v) => set("occupation", v)} />
            </div>
          )}

          {/* STEP 6 — Photos */}
          {step === 6 && (
            <div className="space-y-4">
              <p className="text-sm text-gray-400 -mt-2">
                Upload up to <strong className="text-gray-700">6 photos</strong>. First photo must clearly show your face.
              </p>
              <div className="grid grid-cols-3 gap-3">
                {images.map((img, i) => (
                  <div key={i} className="relative aspect-square rounded-xl overflow-hidden border border-gray-200 group">
                    <img src={img.preview} alt="" className="w-full h-full object-cover" />

                    {/* Upload spinner overlay */}
                    {img.uploading && (
                      <div className="absolute inset-0 bg-black/55 flex items-center justify-center">
                        <div className="w-7 h-7 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      </div>
                    )}

                    {/* MAIN badge */}
                    {i === 0 && (
                      <div className="absolute top-1.5 left-1.5 bg-pink-500 text-white text-[10px] px-1.5 py-0.5 rounded-md font-semibold">MAIN</div>
                    )}

                    {/* Uploaded green check */}
                    {img.uploaded && !img.uploading && (
                      <div className="absolute bottom-1.5 right-1.5 bg-green-500 rounded-full p-0.5">
                        <Check size={10} className="text-white" />
                      </div>
                    )}

                    {/* Remove button — hidden while uploading */}
                    {!img.uploading && (
                      <button type="button" onClick={() => removeImage(i)}
                        className="absolute top-1.5 right-1.5 bg-black/60 rounded-full p-0.5 opacity-0 group-hover:opacity-100 transition">
                        <X size={12} className="text-white" />
                      </button>
                    )}
                  </div>
                ))}
                {images.length < 6 && (
                  <button type="button" onClick={() => fileRef.current?.click()}
                    className="aspect-square rounded-xl border-2 border-dashed border-gray-200 flex flex-col items-center justify-center gap-2 text-gray-400 hover:border-pink-400 hover:text-pink-500 transition">
                    <Camera size={22} />
                    <span className="text-xs font-medium">Add photo</span>
                  </button>
                )}
              </div>
              <input ref={fileRef} type="file" accept="image/*" multiple className="hidden" onChange={(e) => addImages(e.target.files)} />
            </div>
          )}

          {/* STEP 5 — Vibes */}
          {step === 5 && (
            <div className="space-y-5">
              <p className="text-sm text-gray-400 -mt-2">All optional — make your profile shine ✨</p>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Hobbies <span className="text-gray-400 font-normal">(pick any)</span></label>
                <div className="flex flex-wrap gap-2">
                  {HOBBY_OPTIONS.map((h) => (
                    <TagButton key={h.value} label={`${h.emoji} ${h.label}`} selected={form.hobbies.includes(h.value)} onClick={() => toggleArray("hobbies", h.value)} />
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Your vibe</label>
                <div className="flex flex-wrap gap-2">
                  {VIBE_OPTIONS.map((v) => (
                    <TagButton key={v.value} label={`${v.emoji} ${v.label}`} selected={form.vibes.includes(v.value)} onClick={() => toggleArray("vibes", v.value)} />
                  ))}
                </div>
              </div>

              {/* Lifestyle chips — single-select per row (tap again to clear) */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">🍷 Drinking</label>
                <div className="flex flex-wrap gap-2">
                  {DRINKING_OPTIONS.map((o) => (
                    <TagButton
                      key={o.value}
                      label={`${o.emoji} ${o.label}`}
                      selected={form.drinking === o.value}
                      onClick={() => set("drinking", form.drinking === o.value ? "" : o.value)}
                    />
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">🚬 Smoking</label>
                <div className="flex flex-wrap gap-2">
                  {SMOKING_OPTIONS.map((o) => (
                    <TagButton
                      key={o.value}
                      label={`${o.emoji} ${o.label}`}
                      selected={form.smoking === o.value}
                      onClick={() => set("smoking", form.smoking === o.value ? "" : o.value)}
                    />
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">💪 Workout</label>
                <div className="flex flex-wrap gap-2">
                  {WORKOUT_OPTIONS.map((o) => (
                    <TagButton
                      key={o.value}
                      label={`${o.emoji} ${o.label}`}
                      selected={form.workout === o.value}
                      onClick={() => set("workout", form.workout === o.value ? "" : o.value)}
                    />
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">🐾 Pets</label>
                <div className="flex flex-wrap gap-2">
                  {PETS_OPTIONS.map((o) => (
                    <TagButton
                      key={o.value}
                      label={`${o.emoji} ${o.label}`}
                      selected={form.pets === o.value}
                      onClick={() => set("pets", form.pets === o.value ? "" : o.value)}
                    />
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">👶 Children</label>
                <div className="grid grid-cols-2 gap-2">
                  {CHILDREN_OPTIONS.map((o) => (
                    <SelectButton
                      key={o.value}
                      label={o.label}
                      selected={form.children === o.value}
                      onClick={() => set("children", form.children === o.value ? "" : o.value)}
                    />
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">🍽️ Diet</label>
                <div className="grid grid-cols-2 gap-2">
                  {DIET_OPTIONS.map((o) => (
                    <SelectButton
                      key={o.value}
                      label={o.label}
                      selected={form.diet === o.value}
                      onClick={() => set("diet", form.diet === o.value ? "" : o.value)}
                    />
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <InputField
                  label="Height (cm)"
                  type="number"
                  placeholder="e.g. 170"
                  value={form.height_cm}
                  onChange={(v) => set("height_cm", v)}
                  min={120}
                  max={230}
                />
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Religion</label>
                  <select
                    value={RELIGION_OPTIONS.includes(form.religion) ? form.religion : (form.religion ? "Other" : "")}
                    onChange={(e) => set("religion", e.target.value === "Other" ? (form.religion && !RELIGION_OPTIONS.includes(form.religion) ? form.religion : "") : e.target.value)}
                    className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-pink-500 bg-white text-sm"
                  >
                    <option value="">Select…</option>
                    {RELIGION_OPTIONS.map((r) => (
                      <option key={r} value={r}>{r}</option>
                    ))}
                  </select>
                  {/* Free-text fallback when user picks "Other" */}
                  {(form.religion && !RELIGION_OPTIONS.includes(form.religion)) ||
                   (RELIGION_OPTIONS.includes(form.religion) && form.religion === "Other") ? (
                    <input
                      type="text"
                      value={RELIGION_OPTIONS.includes(form.religion) ? "" : form.religion}
                      onChange={(e) => set("religion", e.target.value)}
                      placeholder="Your religion"
                      className="mt-2 w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500"
                    />
                  ) : null}
                </div>
              </div>

              <MultiSelectDropdown
                label="Languages"
                options={LANGUAGE_OPTIONS}
                selected={form.languages || []}
                onChange={(v) => set("languages", v)}
                placeholder="Select languages you speak"
              />

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  ✨ Your ideal first date
                </label>
                <textarea
                  value={form.first_date_idea}
                  onChange={(e) => set("first_date_idea", e.target.value)}
                  rows={2}
                  maxLength={200}
                  placeholder="Coffee and a long walk? A concert? Cooking together?"
                  className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent transition resize-none text-sm"
                />
                <p className="text-right text-xs text-gray-400 mt-1">{(form.first_date_idea || "").length}/200</p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Relationship status</label>
                <div className="grid grid-cols-2 gap-2">
                  {RELATIONSHIP_STATUSES.map((r) => (
                    <SelectButton key={r.value} label={r.label} selected={form.relationship_status === r.value} onClick={() => set("relationship_status", form.relationship_status === r.value ? "" : r.value)} />
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Bio <span className="text-gray-400 font-normal">(optional)</span>
                </label>
                <textarea
                  value={form.bio} onChange={(e) => set("bio", e.target.value)}
                  rows={3} maxLength={300}
                  placeholder="Tell people a bit about yourself…"
                  className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent transition resize-none text-sm"
                />
                <p className="text-right text-xs text-gray-400 mt-1">{form.bio.length}/300</p>
              </div>
            </div>
          )}

          {/* STEP 7 — Face verification (skippable) */}
          {step === 7 && (
            <FaceVerificationStep
              onFinish={handleVerificationFinish}
              onSkip={() => navigate("/dashboard")}
              loading={loading}
              setError={setError}
            />
          )}

          {/* Navigation — hidden on the verification step (it has its own controls) */}
          {step !== 7 && (
            <div className="mt-8 flex items-center gap-3">
              {step > 1 && (
                <button type="button" onClick={() => { setError(""); setStep((s) => s - 1); }}
                  className="flex items-center gap-1.5 px-5 py-3 rounded-xl border border-gray-200 text-gray-600 hover:border-gray-300 hover:bg-gray-50 transition text-sm font-medium">
                  <ChevronLeft size={16} /> Back
                </button>
              )}
              <button
                type="button" onClick={handleNext}
                disabled={loading || uploadingImages}
                className="flex-1 flex items-center justify-center gap-2 py-3 rounded-xl bg-gradient-to-r from-pink-500 to-pink-600 text-white font-semibold hover:from-pink-600 hover:to-pink-700 transition disabled:opacity-50 text-sm shadow-md shadow-pink-100"
              >
                {loading || uploadingImages ? (
                  <span className="flex items-center gap-2">
                    <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" /> Please wait…
                  </span>
                ) : step === 6 ? (
                  <><Camera size={16} /> Upload &amp; continue</>
                ) : step === 5 ? (
                  <><Check size={16} /> Save &amp; continue</>
                ) : (
                  <>Continue <ArrowRight size={16} /></>
                )}
              </button>
            </div>
          )}

          {step === 1 && (
            <p className="mt-5 text-center text-sm text-gray-500">
              Already have an account?{" "}
              <Link to="/login" className="text-pink-600 font-semibold hover:text-pink-700">Sign in</Link>
            </p>
          )}
          {step === 4 && (
            <button type="button" onClick={() => { setError(""); setStep((s) => s + 1); }}
              className="w-full mt-3 text-sm text-gray-400 hover:text-gray-600 transition">
              Skip this step →
            </button>
          )}
        </div>
      </div>

      {/* ── Crop Modal ────────────────────────────────────────────────────── */}
      {cropSrc && (
        <div className="fixed inset-0 z-50 bg-black/80 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl w-full max-w-sm shadow-2xl overflow-hidden flex flex-col">
            {/* Header */}
            <div className="px-5 py-4 border-b border-gray-100">
              <h3 className="font-semibold text-gray-900 text-base">Crop Photo</h3>
              <p className="text-xs text-gray-400 mt-0.5">Drag to position · Scroll to zoom</p>
            </div>
            {/* Cropper area */}
            <div className="relative w-full bg-gray-900" style={{ height: 300 }}>
              <Cropper
                image={cropSrc}
                crop={crop}
                zoom={zoom}
                aspect={1}
                onCropChange={setCrop}
                onZoomChange={setZoom}
                onCropComplete={(_, pixels) => setCroppedAreaPixels(pixels)}
              />
            </div>
            {/* Zoom slider */}
            <div className="px-5 pt-3 pb-1">
              <input
                type="range" min={1} max={3} step={0.05}
                value={zoom}
                onChange={(e) => setZoom(Number(e.target.value))}
                className="w-full accent-pink-500"
              />
            </div>
            {/* Actions */}
            <div className="px-5 pb-5 flex gap-3">
              <button type="button" onClick={handleCropCancel}
                className="flex-1 py-2.5 rounded-xl border border-gray-200 text-gray-600 text-sm font-medium hover:bg-gray-50 transition">
                Cancel
              </button>
              <button type="button" onClick={handleCropConfirm}
                className="flex-1 py-2.5 rounded-xl bg-gradient-to-r from-pink-500 to-rose-500 text-white text-sm font-semibold shadow hover:opacity-90 transition">
                Use Photo
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Face verification step ──────────────────────────────────────────────────
// Camera feed with an oval face-frame overlay. Uses the browser's FaceDetector
// API when available to confirm a clear face is visible; otherwise accepts the
// capture after the user confirms. The resulting JPEG blob is handed to onFinish.
// `onSkip` lets users bypass verification during signup (they can verify later
// from their profile page) — but unverified users are hidden from Discover and
// blocked from sending match requests, so the UX nudges them to finish it.
function FaceVerificationStep({ onFinish, onSkip, loading, setError }) {
  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const streamRef = useRef(null);
  const [phase, setPhase] = useState("idle");   // idle | live | captured | checking
  const [preview, setPreview] = useState(null); // { url, blob }
  const [detectorSupported] = useState(() =>
    typeof window !== "undefined" && "FaceDetector" in window
  );
  const [localError, setLocalError] = useState("");

  // Start camera once the step is shown
  useEffect(() => {
    startCamera();
    return () => stopCamera();
    // eslint-disable-next-line
  }, []);

  async function startCamera() {
    setLocalError("");
    setError("");
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "user", width: { ideal: 720 }, height: { ideal: 720 } },
        audio: false,
      });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play().catch(() => {});
      }
      setPhase("live");
    } catch (e) {
      setLocalError("Camera access denied. Please allow camera to verify your identity.");
      setPhase("idle");
    }
  }

  function stopCamera() {
    streamRef.current?.getTracks().forEach(t => t.stop());
    streamRef.current = null;
  }

  async function capture() {
    const video = videoRef.current;
    if (!video || video.readyState < 2) return;
    setPhase("checking");
    setLocalError("");

    const canvas = canvasRef.current || document.createElement("canvas");
    const w = video.videoWidth || 640;
    const h = video.videoHeight || 640;
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext("2d");
    // Mirror so the saved image matches what the user saw
    ctx.save();
    ctx.translate(w, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(video, 0, 0, w, h);
    ctx.restore();

    // Optional face-presence check (Chrome/Edge desktop & Android only)
    if (detectorSupported) {
      try {
        const detector = new window.FaceDetector({ fastMode: true });
        const faces = await detector.detect(canvas);
        if (faces.length === 0) {
          setLocalError("We couldn't find a clear face. Please center your face in the oval and try again.");
          setPhase("live");
          return;
        }
        if (faces.length > 1) {
          setLocalError("Multiple faces detected. Please take the selfie alone.");
          setPhase("live");
          return;
        }
        // Require the face to fill a reasonable portion of the frame
        const face = faces[0];
        const areaRatio = (face.boundingBox.width * face.boundingBox.height) / (w * h);
        if (areaRatio < 0.08) {
          setLocalError("Face too small — please move closer and try again.");
          setPhase("live");
          return;
        }
      } catch {
        // Detector failed — accept the capture rather than blocking verification
      }
    }

    canvas.toBlob((blob) => {
      if (!blob) {
        setLocalError("Couldn't capture the image. Please try again.");
        setPhase("live");
        return;
      }
      setPreview({ blob, url: URL.createObjectURL(blob) });
      setPhase("captured");
      stopCamera();
    }, "image/jpeg", 0.9);
  }

  async function retake() {
    if (preview?.url) URL.revokeObjectURL(preview.url);
    setPreview(null);
    setLocalError("");
    await startCamera();
  }

  function confirm() {
    if (preview?.blob) onFinish(preview.blob);
  }

  return (
    <div className="space-y-4">
      {localError && (
        <div className="flex items-start gap-2 p-3 bg-amber-50 border border-amber-200 rounded-xl text-amber-700 text-xs">
          <span>⚠️</span> {localError}
        </div>
      )}

      {phase === "captured" && preview ? (
        <div className="space-y-3">
          <div className="relative mx-auto w-64 h-64 rounded-3xl overflow-hidden border-2 border-pink-200 bg-gray-100">
            <img src={preview.url} alt="Your selfie" className="w-full h-full object-cover" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <button
              type="button"
              onClick={retake}
              disabled={loading}
              className="flex items-center justify-center gap-2 py-3 rounded-xl border border-gray-200 text-gray-700 font-semibold hover:bg-gray-50 transition text-sm disabled:opacity-50"
            >
              <RefreshCw size={15} /> Retake
            </button>
            <button
              type="button"
              onClick={confirm}
              disabled={loading}
              className="flex items-center justify-center gap-2 py-3 rounded-xl bg-gradient-to-r from-pink-500 to-pink-600 text-white font-semibold hover:from-pink-600 hover:to-pink-700 transition text-sm shadow-md shadow-pink-100 disabled:opacity-50"
            >
              {loading
                ? <><span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" /> Saving…</>
                : <><Check size={16} /> Verify &amp; finish</>
              }
            </button>
          </div>
        </div>
      ) : (
        <div className="space-y-3">
          <div className="relative mx-auto w-64 h-64 rounded-3xl overflow-hidden bg-gray-900">
            <video
              ref={videoRef}
              playsInline
              muted
              className="w-full h-full object-cover"
              style={{ transform: "scaleX(-1)" }}
            />
            {/* Oval face-frame overlay */}
            <svg viewBox="0 0 100 100" className="absolute inset-0 w-full h-full pointer-events-none" preserveAspectRatio="none">
              <defs>
                <mask id="faceMask">
                  <rect width="100" height="100" fill="white" />
                  <ellipse cx="50" cy="50" rx="32" ry="42" fill="black" />
                </mask>
              </defs>
              <rect width="100" height="100" fill="rgba(0,0,0,0.45)" mask="url(#faceMask)" />
              <ellipse
                cx="50" cy="50" rx="32" ry="42"
                fill="none" stroke="white" strokeOpacity="0.85" strokeWidth="0.6"
                strokeDasharray="1.5 1.5"
              />
            </svg>
            {phase === "checking" && (
              <div className="absolute inset-0 flex items-center justify-center bg-black/40">
                <span className="text-white text-xs font-medium flex items-center gap-2">
                  <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                  Checking…
                </span>
              </div>
            )}
          </div>
          <p className="text-center text-xs text-gray-500">
            Center your face inside the oval, then tap capture.
          </p>
          <button
            type="button"
            onClick={capture}
            disabled={phase !== "live"}
            className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-gradient-to-r from-pink-500 to-pink-600 text-white font-semibold hover:from-pink-600 hover:to-pink-700 transition text-sm shadow-md shadow-pink-100 disabled:opacity-50"
          >
            <Camera size={16} /> Capture selfie
          </button>
          {!detectorSupported && (
            <p className="text-[11px] text-gray-400 text-center">
              Face auto-check not supported on this browser — please make sure your face is clearly visible.
            </p>
          )}
        </div>
      )}

      {onSkip && phase !== "captured" && (
        <button
          type="button"
          onClick={() => { stopCamera(); onSkip(); }}
          disabled={loading}
          className="w-full text-center text-sm text-gray-400 hover:text-gray-600 py-1 transition disabled:opacity-50"
        >
          Skip for now — I'll verify later
        </button>
      )}
      <p className="text-[11px] text-gray-400 text-center leading-relaxed">
        Verified profiles are the only ones shown in Discover and allowed to send requests. You can verify anytime from your profile.
      </p>

      <canvas ref={canvasRef} className="hidden" />
    </div>
  );
}
