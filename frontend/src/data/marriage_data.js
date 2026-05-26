// ─── Indian state-based caste & religion data for Serious Marriage onboarding ──
// Each state lists its prominent communities. "No Caste" + "Any Caste" are always
// prepended so users can opt out of caste matching entirely.

export const SPECIAL_CASTE_OPTIONS = ["No Caste", "Any Caste"];

export const STATE_CASTES = {
  "Andhra Pradesh": [
    "Brahmin (Niyogi)", "Brahmin (Vaidiki)", "Kapu", "Kamma", "Khatri",
    "Kshatriya", "Mala", "Madiga", "Mudiraju", "Naidu (Balija)", "Raju (Kshatriya)",
    "Reddy", "Turpu Kapu", "Velama", "Vysya (Komati)", "Yadava", "Other",
  ],
  "Arunachal Pradesh": [
    "Adi", "Apatani", "Garo", "Khampti", "Mishmi", "Monpa", "Nishi", "Nyishi", "Wancho", "Other",
  ],
  "Assam": [
    "Ahom", "Brahmin (Assamese)", "Bodo", "Kalita", "Koch-Rajbongshi",
    "Moran", "Muslim (Assamese)", "Scheduled Caste", "Tea Garden", "Other",
  ],
  "Bihar": [
    "Brahmin (Maithil)", "Brahmin (Saryuparin)", "Bhumihar", "Dhanuk",
    "Kayastha", "Koiri", "Kurmi", "Kushwaha", "Lohar", "Mallah", "Musahar",
    "Rajput", "Teli", "Yadav", "Other",
  ],
  "Chhattisgarh": [
    "Brahmin", "Kurmi (Kanwar)", "Lodhia", "Rajput", "Satnami", "Teli", "Yadav", "Other",
  ],
  "Delhi": [
    "Agarwal", "Arora", "Brahmin", "Jat", "Khatri", "Punjabi Khatri",
    "Rajput", "Saini", "Scheduled Caste", "Yadav", "Other",
  ],
  "Goa": [
    "Catholic (Goan)", "CKP (Chandraseniya Kayastha Prabhu)",
    "GSB (Goud Saraswat Brahmin)", "Kunbi", "Maratha", "Other",
  ],
  "Gujarat": [
    "Anavil Brahmin", "Bania (Kapol)", "Bania (Lohana)", "Bania (Porwal)",
    "Bania (Visa Oswal)", "Bharwad", "Darbar (Rajput)", "Koli", "Nagar Brahmin",
    "Patidar (Kadva)", "Patidar (Leuva)", "Rabari", "Soni", "Suthar", "Other",
  ],
  "Haryana": [
    "Agarwal (Bania)", "Ahir (Yadav)", "Brahmin", "Chamar", "Jat",
    "Rajput", "Ror", "Saini", "Scheduled Caste", "Other",
  ],
  "Himachal Pradesh": [
    "Brahmin (Himachali)", "Girtha", "Kanait", "Rajput", "Scheduled Caste (Chamar/Koli)", "Other",
  ],
  "Jharkhand": [
    "Brahmin", "Kurmi", "Rajput", "Santali (Tribal)", "Scheduled Caste", "Yadav", "Other",
  ],
  "Karnataka": [
    "Bunt", "Devanga", "Gowda (Vokkaliga)", "Iyengar", "Jain (Digambara)", "Jain (Shvetambara)",
    "Kuruba (Shepherd)", "Lingayat (Banajiga)", "Lingayat (Panchamasali)", "Lingayat (Sadara)",
    "Madiga", "Nayaka", "SC (Holeya)", "Shivalli Brahmin", "Smartha Brahmin",
    "Voddina Okkaliga", "Vokkaliga (Gangadikara)", "Vokkaliga (Morasu)", "Other",
  ],
  "Kerala": [
    "Brahmin (Namboothiri)", "Christian (CSI / Latin)", "Christian (Jacobite / Syrian Orthodox)",
    "Christian (Mar Thoma)", "Christian (RC / Syro-Malabar)", "Ezhava / Thiyya",
    "Kshatriya", "Mappila (Muslim)", "Menon", "Mudaliar", "Nair",
    "Nadar", "Viswakarma", "Other",
  ],
  "Madhya Pradesh": [
    "Brahmin (Malvi)", "Jain", "Jat", "Kurmi", "Lodhi Rajput", "Patel (Kurmi)",
    "Rajput", "Teli", "Yadav", "Other",
  ],
  "Maharashtra": [
    "Agri", "Bhandari", "Brahmin (Deshastha)", "Brahmin (Karhade)",
    "Brahmin (Konkanastha / Chitpavan)", "Chambhar", "CKP",
    "GSB (Goud Saraswat Brahmin)", "Kunbi", "Koli", "Lingayat",
    "Mahar (Buddhist)", "Mali", "Maratha", "Matang", "Sonare (Soni)",
    "Teli", "Vanjari", "Other",
  ],
  "Manipur": [
    "Brahmin (Meitei)", "Meitei / Meetei", "Pangal (Meitei Muslim)",
    "Scheduled Tribe (Kuki-Zo, Naga)", "Other",
  ],
  "Meghalaya": ["Garo", "Jaintia / Pnar", "Khasi", "Other"],
  "Mizoram": ["Hmar", "Mizo / Lushai", "Ralte", "Other"],
  "Nagaland": ["Angami", "Ao", "Konyak", "Lotha", "Sumi / Sema", "Other"],
  "Odisha": [
    "Brahmin (Panchadravida)", "Chasa", "Gouda", "Karan (Kayastha)",
    "Khandayat", "Scheduled Caste (Chamar)", "Scheduled Tribe", "Teli", "Other",
  ],
  "Punjab": [
    "Arora", "Brahmin", "Jat Sikh", "Khatri", "Mazhabi Sikh",
    "Ramgarhia", "Ramdasia", "Saini", "Scheduled Caste", "Other",
  ],
  "Rajasthan": [
    "Agarwal (Vaishya)", "Brahmin (Dadhich)", "Brahmin (Pushkarna)",
    "Gujar", "Jat", "Maheshwari", "Mali", "Meena (Tribal)", "Meghwal",
    "Oswal Jain", "Rajput (Chauhan)", "Rajput (Rathore)", "Rajput (Shekhawat)",
    "Yadav", "Other",
  ],
  "Sikkim": ["Bhutia", "Brahmin (Nepali)", "Lepcha", "Rai", "Other"],
  "Tamil Nadu": [
    "Brahmin (Iyer)", "Brahmin (Iyengar)", "Chettiar (Nagarathar)",
    "Gounder (Kongu Vellala)", "Mudaliar (Agamudayar)", "Mudaliar (Arcot)",
    "Mudaliar (Saiva)", "Nadar", "Naicker", "Pillai (Nair)", "Pillai (Vellala)",
    "Thevar (Kallars)", "Thevar (Mukkulathor)", "Udayar", "Vanniakula Kshatriya",
    "Vellalar (Saiva)", "Other",
  ],
  "Telangana": [
    "Brahmin (Niyogi)", "Brahmin (Vaidiki)", "Goud", "Kapu",
    "Kamma", "Madiga", "Mala", "Munnuru Kapu",
    "Padmashali", "Raju", "Reddy", "Yadava", "Other",
  ],
  "Tripura": ["Bengali Hindu (Brahmin)", "Debbarma (Tribal)", "Jamatia", "Reang", "Other"],
  "Uttar Pradesh": [
    "Bhumihar", "Brahmin (Gaur)", "Brahmin (Kanyakubja)", "Brahmin (Saryuparin)",
    "Chamar", "Jat", "Jatav", "Kayastha", "Koiri (Kushwaha)",
    "Kumhar", "Kurmi", "Lodha / Lodhi", "Pasi", "Rajput (Bisen)",
    "Rajput (Chauhan)", "Rajput (Rathore)", "Rajput (Sengar)", "Teli",
    "Vaishya (Agarwal)", "Vaishya (Gupta)", "Yadav", "Other",
  ],
  "Uttarakhand": [
    "Brahmin (Kumaoni)", "Brahmin (Garhwali)", "Rajput (Garhwali)",
    "Rajput (Kumaoni)", "Scheduled Caste (Dom)", "Other",
  ],
  "West Bengal": [
    "Baidya", "Bengali Brahmin (Kulin)", "Bengali Brahmin (Rarhi)",
    "Bene Israel", "Goala (Yadav)", "Kaibarta", "Kayastha",
    "Mahishya", "Namasudra", "Rajbanshi", "Sadgop", "Sutradhar", "Tili",
    "Other",
  ],
};

// Sub-castes for a given caste entry. Key = caste label exactly as in STATE_CASTES.
// Only the castes large enough to warrant sub-divisions are listed;
// all others default to just "No Sub-caste" and "Any Sub-caste".
export const CASTE_SUB_CASTES = {
  "Brahmin (Deshastha)": ["Rigvedi", "Yajurvedi"],
  "Brahmin (Konkanastha / Chitpavan)": [],
  "Brahmin (Karhade)": [],
  "Maratha": ["Chandraseniya (96 Kuli)", "Kunbi Maratha", "Other Maratha"],
  "Rajput": ["Chauhan", "Rathore", "Shekhawat", "Sisodia", "Tomara", "Other Rajput"],
  "Rajput (Chauhan)": ["Hamirpur", "Chandela", "Other Chauhan"],
  "Rajput (Rathore)": ["Bikaner", "Jodhpur", "Other Rathore"],
  "Rajput (Shekhawat)": [],
  "Jat Sikh": ["Majha", "Malwa", "Doaba"],
  "Jat": ["Ahirwal", "Desh Haryana", "UP Jat", "Other Jat"],
  "Kamma": ["Kamma (AP)", "Kamma (Telangana)", "Other Kamma"],
  "Reddy": ["Desai Reddy", "Kapu Reddy", "Mudiraj Reddy", "Other Reddy"],
  "Lingayat (Panchamasali)": ["Panchamasali", "Banajiga Lingayat"],
  "Vokkaliga (Gangadikara)": [],
  "Vokkaliga (Morasu)": [],
  "Gowda (Vokkaliga)": ["Gangadikara", "Morasu", "Okkaliga Gowda"],
  "Nair": ["Kiriyathil Nair", "Kaduppattan Nair", "Kizhakke Nair"],
  "Ezhava / Thiyya": ["Ezhava (Kerala)", "Thiyya (Malabar)"],
  "Patidar (Kadva)": [],
  "Patidar (Leuva)": [],
  "Agarwal (Vaishya)": ["Agarwal (Vaishnavansh)", "Agarwal (Bansal)"],
  "Kayastha": ["Bengal Kayastha", "UP Kayastha", "Bihar Kayastha"],
  "Yadav": ["Ahir (Harita)", "Goala", "Ghosi", "Gwala", "Rawat", "Other Yadav"],
  "Khatri": ["Arora Khatri", "Kapoor", "Mehra", "Sethi", "Suri", "Tandon"],
};

// Sub-castes fallback for any caste not explicitly listed above
export const DEFAULT_SUB_CASTES = [];

export function getSubCastes(caste) {
  if (!caste || SPECIAL_CASTE_OPTIONS.includes(caste)) return [];
  return CASTE_SUB_CASTES[caste] || DEFAULT_SUB_CASTES;
}

export function getCastesForState(state) {
  return STATE_CASTES[state] || [];
}

// ─── Religion + Sub-religion data ───────────────────────────────────────────

export const MARRIAGE_RELIGIONS = [
  "No Religion",
  "Any Religion",
  "Hindu",
  "Muslim",
  "Christian",
  "Sikh",
  "Jain",
  "Buddhist",
  "Parsi / Zoroastrian",
  "Jewish",
  "Bahai",
  "Other",
];

export const RELIGION_SUB_RELIGIONS = {
  Hindu: [
    "Any Sub-religion",
    "No Sub-religion",
    "Shaiva",
    "Vaishnava",
    "Shakta",
    "Smartha",
    "Arya Samaj",
    "Brahmo Samaj",
    "ISKCON / Vaishnava",
    "Lingayat",
    "Swaminarayan",
    "Other Hindu",
  ],
  Muslim: [
    "Any Sub-religion",
    "No Sub-religion",
    "Sunni (Hanafi)",
    "Sunni (Shafi'i)",
    "Sunni (Maliki)",
    "Shia (Ithna Ashari / Twelver)",
    "Shia (Ismaili)",
    "Bohra (Dawoodi)",
    "Bohra (Sulaimani)",
    "Ahmadiyya",
    "Sufi",
    "Other Muslim",
  ],
  Christian: [
    "Any Sub-religion",
    "No Sub-religion",
    "Catholic (Roman)",
    "Catholic (Syro-Malabar)",
    "Catholic (Syro-Malankara)",
    "Catholic (Latin)",
    "Church of South India (CSI)",
    "Church of North India (CNI)",
    "Mar Thoma Syrian",
    "Jacobite Syrian Orthodox",
    "Malankara Orthodox",
    "Pentecostal",
    "Baptist",
    "Methodist",
    "Lutheran",
    "Salvation Army",
    "Other Christian",
  ],
  Sikh: [
    "Any Sub-religion",
    "No Sub-religion",
    "Keshdhari",
    "Sahajdhari",
    "Nihang",
    "Namdhari",
    "Nirankari (Sant Nirankari)",
    "Ravidasia",
    "Other Sikh",
  ],
  Jain: [
    "Any Sub-religion",
    "No Sub-religion",
    "Digambara",
    "Shvetambara (Murtipujak)",
    "Shvetambara (Sthanakvasi)",
    "Shvetambara (Terapanthi)",
    "Other Jain",
  ],
  Buddhist: [
    "Any Sub-religion",
    "No Sub-religion",
    "Theravada",
    "Mahayana (Zen)",
    "Mahayana (Pure Land)",
    "Vajrayana (Tibetan)",
    "Ambedkarite / Navayana",
    "Other Buddhist",
  ],
  "Parsi / Zoroastrian": [
    "Any Sub-religion",
    "No Sub-religion",
    "Shehenshahi",
    "Kadimi",
    "Fasli",
    "Other Zoroastrian",
  ],
};

export function getSubReligions(religion) {
  if (!religion || religion === "No Religion" || religion === "Any Religion") return [];
  return RELIGION_SUB_RELIGIONS[religion] || ["Any Sub-religion", "No Sub-religion"];
}
