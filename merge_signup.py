import re
import os

p_ref = r'C:\Users\ajayk\Downloads\Signup.jsx'
p_cur = r'c:\Users\ajayk\Downloads\mheartm-main\mheartm-main\frontend\src\pages\Signup.jsx'

with open(p_ref, 'r', encoding='utf-8') as f:
    ref_code = f.read()

with open(p_cur, 'r', encoding='utf-8') as f:
    cur_code = f.read()

# 1. We start with the reference code because it has all the complex new Google UI, validations, and marriage logic.
# 2. We will inject the preserved features from cur_code into the new ref_code.

merged = ref_code

# PRESERVE 1: MultiSelectDropdown import
if 'import MultiSelectDropdown' not in merged:
    merged = merged.replace('import BrandLogo from "../components/BrandLogo";', 'import BrandLogo from "../components/BrandLogo";\nimport MultiSelectDropdown from "../components/MultiSelectDropdown";')

# PRESERVE 2: HOBBY_OPTIONS
hobby_match = re.search(r'const HOBBY_OPTIONS = \[.*?\];', cur_code, flags=re.DOTALL)
if hobby_match:
    merged = re.sub(r'const HOBBY_OPTIONS = \[.*?\];', hobby_match.group(0), merged, flags=re.DOTALL)

# PRESERVE 3: VIBE_OPTIONS
vibe_match = re.search(r'const VIBE_OPTIONS = \[.*?\];', cur_code, flags=re.DOTALL)
if vibe_match:
    merged = re.sub(r'const VIBE_OPTIONS = \[.*?\];', vibe_match.group(0), merged, flags=re.DOTALL)

# PRESERVE 4: LANGUAGE_OPTIONS
lang_match = re.search(r'const LANGUAGE_OPTIONS = \[.*?\];', cur_code, flags=re.DOTALL)
if lang_match:
    # Insert it right before HOBBY_OPTIONS
    merged = merged.replace('const HOBBY_OPTIONS', lang_match.group(0) + '\n\nconst HOBBY_OPTIONS')

# PRESERVE 5: form state for workplace and college_university
merged = merged.replace('education_level: "", occupation: "",', 'education_level: "", occupation: "", college_university: "", workplace: "",')

# PRESERVE 6: handleSaveProfile payload for workplace and college_university
merged = merged.replace('occupation: form.occupation || undefined,', 'occupation: form.occupation || undefined,\n        college_university: form.college_university?.trim() || undefined,\n        workplace: form.workplace?.trim() || undefined,')

# PRESERVE 7: UI for workplace and college_university
ui_to_insert = """              <InputField icon={<Briefcase size={16} />} label="College / University (optional)" placeholder="e.g. Stanford University" value={form.college_university} onChange={(v) => set("college_university", v)} />
              <InputField icon={<Briefcase size={16} />} label="Workplace (optional)" placeholder="e.g. Google, Self-employed" value={form.workplace} onChange={(v) => set("workplace", v)} />"""
merged = merged.replace('<InputField icon={<Briefcase size={16} />} label="Occupation"', ui_to_insert + '\n              <InputField icon={<Briefcase size={16} />} label="Occupation"')

# PRESERVE 8: TagButtons for Hobbies and Vibes in UI
merged = merged.replace('<TagButton key={h} label={h} selected={form.hobbies.includes(h)} onClick={() => toggleArray("hobbies", h)} />', '<TagButton key={h.value} label={`${h.emoji} ${h.label}`} selected={form.hobbies.includes(h.value)} onClick={() => toggleArray("hobbies", h.value)} />')
merged = merged.replace('<TagButton key={v} label={v} selected={form.vibes.includes(v)} onClick={() => toggleArray("vibes", v)} />', '<TagButton key={v.value} label={`${v.emoji} ${v.label}`} selected={form.vibes.includes(v.value)} onClick={() => toggleArray("vibes", v.value)} />')

# PRESERVE 9: Languages UI block
lang_ui_ref = """              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Languages <span className="text-gray-400 font-normal">(comma-separated)</span>
                </label>
                <input
                  type="text"
                  value={(form.languages || []).join(", ")}
                  onChange={(e) =>
                    set(
                      "languages",
                      e.target.value
                        .split(",")
                        .map((s) => s.trim())
                        .filter(Boolean)
                    )
                  }
                  placeholder="e.g. English, Hindi, Tamil"
                  className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent transition text-sm"
                />
              </div>"""

lang_ui_cur = """              <MultiSelectDropdown
                label="Languages"
                options={LANGUAGE_OPTIONS}
                selected={form.languages || []}
                onChange={(v) => set("languages", v)}
                placeholder="Select languages you speak"
              />"""

merged = merged.replace(lang_ui_ref, lang_ui_cur)

with open(p_cur, 'w', encoding='utf-8') as f:
    f.write(merged)

print("Merge successful.")
