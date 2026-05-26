import re
import traceback

try:
    p = r'c:\Users\ajayk\Downloads\mheartm-main\mheartm-main\frontend\src\pages\Dashboard.jsx'
    with open(p, 'r', encoding='utf-8') as f:
        code = f.read()

    # 1. Imports
    if 'getCastesForState' not in code:
        code = code.replace(
            'import { COUNTRIES, INDIA_STATES, INDIA_STATE_NAMES } from "../data/locations";',
            'import { COUNTRIES, INDIA_STATES, INDIA_STATE_NAMES } from "../data/locations";\nimport {\n  MARRIAGE_RELIGIONS, SPECIAL_CASTE_OPTIONS,\n  getCastesForState, getSubCastes, getSubReligions,\n} from "../data/marriage_data";'
        )

    # 2. Form state
    if 'caste: profile?.caste' not in code:
        code = code.replace(
            'relationship_goal: profile?.relationship_goal || "",',
            'relationship_goal: profile?.relationship_goal || "",\n      caste: profile?.caste || "",\n      sub_caste: profile?.sub_caste || "",\n      sub_religion: profile?.sub_religion || "",\n      annual_income: profile?.annual_income || "",'
        )

    # 3. Payload
    if 'caste: form.caste' not in code:
        code = code.replace(
            'relationship_goal: form.relationship_goal || undefined,',
            'relationship_goal: form.relationship_goal || undefined,\n        caste: form.caste?.trim() || undefined,\n        sub_caste: form.sub_caste?.trim() || undefined,\n        sub_religion: form.sub_religion?.trim() || undefined,\n        annual_income: form.annual_income || undefined,'
        )

    # 4. Profile Edit UI Fields
    ui_insert = """
            {/* Serious Marriage Matrimony Fields */}
            {form.relationship_goal === "serious_marriage" && (
              <div className="col-span-1 sm:col-span-2 space-y-4 pt-4 border-t border-gray-100">
                <div className="p-3 bg-purple-50 rounded-lg text-xs text-purple-700">
                  <span className="font-medium">Serious Matrimony Pool</span> — These details are only visible to others looking for marriage.
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">Caste</label>
                    <select
                      value={form.caste}
                      onChange={(e) => setForm(f => ({ ...f, caste: e.target.value, sub_caste: "" }))}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white"
                    >
                      <option value="">—</option>
                      {SPECIAL_CASTE_OPTIONS.map(c => <option key={c} value={c}>{c}</option>)}
                      {profile.state && getCastesForState(profile.state).length > 0 && (
                        <optgroup label={`— ${profile.state} communities —`}>
                          {getCastesForState(profile.state).map(c => <option key={c} value={c}>{c}</option>)}
                        </optgroup>
                      )}
                      <option value="Other">Other</option>
                    </select>
                  </div>

                  {form.caste && !SPECIAL_CASTE_OPTIONS.includes(form.caste) && (
                    <div>
                      <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">Sub-caste</label>
                      <select
                        value={form.sub_caste}
                        onChange={(e) => setForm(f => ({ ...f, sub_caste: e.target.value }))}
                        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white"
                      >
                        <option value="">—</option>
                        <option value="No Sub-caste">No Sub-caste</option>
                        <option value="Any Sub-caste">Any Sub-caste</option>
                        {getSubCastes(form.caste).map(s => <option key={s} value={s}>{s}</option>)}
                        <option value="Other">Other</option>
                      </select>
                    </div>
                  )}

                  {form.religion && form.religion !== "No Religion" && form.religion !== "Any Religion" && getSubReligions(form.religion).length > 0 && (
                    <div>
                      <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">Sub-religion / Sect</label>
                      <select
                        value={form.sub_religion}
                        onChange={(e) => setForm(f => ({ ...f, sub_religion: e.target.value }))}
                        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white"
                      >
                        <option value="">—</option>
                        {getSubReligions(form.religion).map(s => <option key={s} value={s}>{s}</option>)}
                      </select>
                    </div>
                  )}

                  <div>
                    <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">Annual Income</label>
                    <select
                      value={form.annual_income}
                      onChange={(e) => setForm(f => ({ ...f, annual_income: e.target.value }))}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white"
                    >
                      <option value="">—</option>
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
              </div>
            )}
"""
    if 'Serious Marriage Matrimony Fields' not in code:
        code = code.replace(
            '<EditReligion value={form.religion} onChange={(v) => setForm(f => ({ ...f, religion: v }))} />',
            '<EditReligion value={form.religion} onChange={(v) => setForm(f => ({ ...f, religion: v }))} />\n' + ui_insert
        )

    # 5. Display the matrimony fields on the profile view.
    display_insert = """
                {profile.caste && profile.relationship_goal === "serious_marriage" && (
                  <DetailChip Icon={Star} label="Caste" value={`${profile.caste}${profile.sub_caste ? ` (${profile.sub_caste})` : ""}`} />
                )}
                {profile.sub_religion && profile.relationship_goal === "serious_marriage" && (
                  <DetailChip Icon={Sparkles} label="Sect" value={profile.sub_religion} />
                )}
"""
    if 'profile.caste && profile.relationship_goal' not in code:
        code = code.replace(
            '<DetailChip Icon={Sparkles} label="Religion" value={profile.religion} />',
            '<DetailChip Icon={Sparkles} label="Religion" value={profile.religion} />' + display_insert
        )

    with open(p, 'w', encoding='utf-8') as f:
        f.write(code)

    print("Success")
except Exception as e:
    traceback.print_exc()
