import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../dashboard/dashboard_screen.dart';

// ─── Photo entry ──────────────────────────────────────────────────────────────
class _Photo {
  final Uint8List bytes;
  bool uploading;
  bool uploaded;
  String? url;
  _Photo({required this.bytes,
      this.uploading = false, this.uploaded = false, this.url});
}

// ─── India states + cities ───────────────────────────────────────────────────
const Map<String, List<String>> _indiaCities = {
  'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Tirupati', 'Nellore'],
  'Arunachal Pradesh': ['Itanagar', 'Naharlagun', 'Pasighat'],
  'Assam': ['Guwahati', 'Dibrugarh', 'Silchar', 'Jorhat'],
  'Bihar': ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur'],
  'Chhattisgarh': ['Raipur', 'Bhilai', 'Bilaspur', 'Korba'],
  'Goa': ['Panaji', 'Margao', 'Mapusa', 'Vasco da Gama'],
  'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Gandhinagar'],
  'Haryana': ['Gurugram', 'Faridabad', 'Panipat', 'Ambala', 'Karnal'],
  'Himachal Pradesh': ['Shimla', 'Manali', 'Dharamshala', 'Solan'],
  'Jharkhand': ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro'],
  'Karnataka': ['Bengaluru', 'Mysuru', 'Mangaluru', 'Hubballi', 'Belagavi'],
  'Kerala': ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kollam'],
  'Madhya Pradesh': ['Bhopal', 'Indore', 'Jabalpur', 'Gwalior', 'Ujjain'],
  'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad', 'Thane'],
  'Manipur': ['Imphal', 'Churachandpur'],
  'Meghalaya': ['Shillong', 'Tura'],
  'Mizoram': ['Aizawl', 'Lunglei'],
  'Nagaland': ['Kohima', 'Dimapur'],
  'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Berhampur'],
  'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Chandigarh'],
  'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer'],
  'Sikkim': ['Gangtok', 'Namchi'],
  'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem'],
  'Telangana': ['Hyderabad', 'Warangal', 'Karimnagar', 'Nizamabad'],
  'Tripura': ['Agartala', 'Dharmanagar'],
  'Uttar Pradesh': ['Lucknow', 'Kanpur', 'Agra', 'Varanasi', 'Allahabad', 'Noida'],
  'Uttarakhand': ['Dehradun', 'Haridwar', 'Roorkee', 'Haldwani'],
  'West Bengal': ['Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri'],
  'Delhi': ['New Delhi', 'Dwarka', 'Rohini', 'Saket', 'Lajpat Nagar'],
  'Jammu and Kashmir': ['Srinagar', 'Jammu', 'Anantnag'],
  'Ladakh': ['Leh', 'Kargil'],
  'Chandigarh (UT)': ['Chandigarh'],
  'Puducherry': ['Puducherry', 'Karaikal'],
};

const List<String> _countries = [
  'India',
  'United States',
  'United Kingdom',
  'Canada',
  'Australia',
  'Germany',
  'France',
  'UAE',
  'Singapore',
  'Other',
];

// ─── Data lists ───────────────────────────────────────────────────────────────
const List<String> _languagesList = [
  'English', 'Hindi', 'Bengali', 'Telugu', 'Marathi', 'Tamil', 'Urdu', 
  'Gujarati', 'Kannada', 'Malayalam', 'Odia', 'Punjabi', 'Assamese', 
  'Maithili', 'Sanskrit', 'Marwari', 'Bhojpuri', 'Spanish', 'French', 
  'German', 'Mandarin', 'Arabic', 'Russian', 'Portuguese', 'Japanese'
];

const List<String> _hobbiesList = [
  'Reading', 'Travelling', 'Gaming', 'Cooking', 'Fitness', 'Photography',
  'Music', 'Dancing', 'Art', 'Movies', 'Yoga', 'Hiking', 'Writing',
  'Sports', 'Cycling', 'Swimming', 'Gardening', 'Meditation',
];

const List<String> _religionList = [
  'No Religion', 'Any Religion', 'Hindu', 'Muslim', 'Christian', 'Sikh',
  'Jain', 'Buddhist', 'Parsi / Zoroastrian', 'Jewish', 'Bahai',
  'Atheist', 'Other',
];

const List<String> _educationList = [
  'High School', 'Diploma', "Bachelor's", "Master's", 'PhD', 'Other',
];

const List<String> _goalList = [
  'Long-term relationship',
  'Short-term / Casual',
  'Marriage',
  'Serious Matrimony',
  'Friendship first',
  'Just exploring',
];

const Map<String, String> _goalApiValues = {
  'Long-term relationship': 'long_term',
  'Short-term / Casual':    'short_term',
  'Marriage':               'marriage',
  'Serious Matrimony':      'serious_marriage',
  'Friendship first':       'friendship',
  'Just exploring':         'casual',
};

const List<String> _incomeList = [
  'Prefer not to say',
  'Below ₹2 Lakh', '₹2 – 4 Lakh', '₹4 – 6 Lakh', '₹6 – 10 Lakh',
  '₹10 – 15 Lakh', '₹15 – 25 Lakh', '₹25 – 50 Lakh',
  '₹50 Lakh – 1 Crore', 'Above ₹1 Crore',
];

const Map<String, String> _incomeApiValues = {
  'Prefer not to say':     'prefer_not_to_say',
  'Below ₹2 Lakh':        'below_2l',
  '₹2 – 4 Lakh':         '2l_4l',
  '₹4 – 6 Lakh':         '4l_6l',
  '₹6 – 10 Lakh':        '6l_10l',
  '₹10 – 15 Lakh':       '10l_15l',
  '₹15 – 25 Lakh':       '15l_25l',
  '₹25 – 50 Lakh':       '25l_50l',
  '₹50 Lakh – 1 Crore':  '50l_1cr',
  'Above ₹1 Crore':       'above_1cr',
};

const Set<String> _specialCasteOptions = {'No Caste', 'Any Caste'};

// State-based caste lookup — mirrors the website's STATE_CASTES exactly
const Map<String, List<String>> _stateCastes = {
  'Andhra Pradesh': [
    'Brahmin (Niyogi)', 'Brahmin (Vaidiki)', 'Kapu', 'Kamma', 'Khatri',
    'Kshatriya', 'Mala', 'Madiga', 'Mudiraju', 'Naidu (Balija)', 'Raju (Kshatriya)',
    'Reddy', 'Turpu Kapu', 'Velama', 'Vysya (Komati)', 'Yadava', 'Other',
  ],
  'Arunachal Pradesh': [
    'Adi', 'Apatani', 'Garo', 'Khampti', 'Mishmi', 'Monpa', 'Nishi', 'Nyishi', 'Wancho', 'Other',
  ],
  'Assam': [
    'Ahom', 'Brahmin (Assamese)', 'Bodo', 'Kalita', 'Koch-Rajbongshi',
    'Moran', 'Muslim (Assamese)', 'Scheduled Caste', 'Tea Garden', 'Other',
  ],
  'Bihar': [
    'Brahmin (Maithil)', 'Brahmin (Saryuparin)', 'Bhumihar', 'Dhanuk',
    'Kayastha', 'Koiri', 'Kurmi', 'Kushwaha', 'Lohar', 'Mallah', 'Musahar',
    'Rajput', 'Teli', 'Yadav', 'Other',
  ],
  'Chhattisgarh': [
    'Brahmin', 'Kurmi (Kanwar)', 'Lodhia', 'Rajput', 'Satnami', 'Teli', 'Yadav', 'Other',
  ],
  'Delhi': [
    'Agarwal', 'Arora', 'Brahmin', 'Jat', 'Khatri', 'Punjabi Khatri',
    'Rajput', 'Saini', 'Scheduled Caste', 'Yadav', 'Other',
  ],
  'Goa': [
    'Catholic (Goan)', 'CKP (Chandraseniya Kayastha Prabhu)',
    'GSB (Goud Saraswat Brahmin)', 'Kunbi', 'Maratha', 'Other',
  ],
  'Gujarat': [
    'Anavil Brahmin', 'Bania (Kapol)', 'Bania (Lohana)', 'Bania (Porwal)',
    'Bania (Visa Oswal)', 'Bharwad', 'Darbar (Rajput)', 'Koli', 'Nagar Brahmin',
    'Patidar (Kadva)', 'Patidar (Leuva)', 'Rabari', 'Soni', 'Suthar', 'Other',
  ],
  'Haryana': [
    'Agarwal (Bania)', 'Ahir (Yadav)', 'Brahmin', 'Chamar', 'Jat',
    'Rajput', 'Ror', 'Saini', 'Scheduled Caste', 'Other',
  ],
  'Himachal Pradesh': [
    'Brahmin (Himachali)', 'Girtha', 'Kanait', 'Rajput', 'Scheduled Caste (Chamar/Koli)', 'Other',
  ],
  'Jharkhand': [
    'Brahmin', 'Kurmi', 'Rajput', 'Santali (Tribal)', 'Scheduled Caste', 'Yadav', 'Other',
  ],
  'Karnataka': [
    'Bunt', 'Devanga', 'Gowda (Vokkaliga)', 'Iyengar', 'Jain (Digambara)', 'Jain (Shvetambara)',
    'Kuruba (Shepherd)', 'Lingayat (Banajiga)', 'Lingayat (Panchamasali)', 'Lingayat (Sadara)',
    'Madiga', 'Nayaka', 'SC (Holeya)', 'Shivalli Brahmin', 'Smartha Brahmin',
    'Voddina Okkaliga', 'Vokkaliga (Gangadikara)', 'Vokkaliga (Morasu)', 'Other',
  ],
  'Kerala': [
    'Brahmin (Namboothiri)', 'Christian (CSI / Latin)', 'Christian (Jacobite / Syrian Orthodox)',
    'Christian (Mar Thoma)', 'Christian (RC / Syro-Malabar)', 'Ezhava / Thiyya',
    'Kshatriya', 'Mappila (Muslim)', 'Menon', 'Mudaliar', 'Nair',
    'Nadar', 'Viswakarma', 'Other',
  ],
  'Madhya Pradesh': [
    'Brahmin (Malvi)', 'Jain', 'Jat', 'Kurmi', 'Lodhi Rajput', 'Patel (Kurmi)',
    'Rajput', 'Teli', 'Yadav', 'Other',
  ],
  'Maharashtra': [
    'Agri', 'Bhandari', 'Brahmin (Deshastha)', 'Brahmin (Karhade)',
    'Brahmin (Konkanastha / Chitpavan)', 'Chambhar', 'CKP',
    'GSB (Goud Saraswat Brahmin)', 'Kunbi', 'Koli', 'Lingayat',
    'Mahar (Buddhist)', 'Mali', 'Maratha', 'Matang', 'Sonare (Soni)',
    'Teli', 'Vanjari', 'Other',
  ],
  'Manipur': [
    'Brahmin (Meitei)', 'Meitei / Meetei', 'Pangal (Meitei Muslim)',
    'Scheduled Tribe (Kuki-Zo, Naga)', 'Other',
  ],
  'Meghalaya': ['Garo', 'Jaintia / Pnar', 'Khasi', 'Other'],
  'Mizoram': ['Hmar', 'Mizo / Lushai', 'Ralte', 'Other'],
  'Nagaland': ['Angami', 'Ao', 'Konyak', 'Lotha', 'Sumi / Sema', 'Other'],
  'Odisha': [
    'Brahmin (Panchadravida)', 'Chasa', 'Gouda', 'Karan (Kayastha)',
    'Khandayat', 'Scheduled Caste (Chamar)', 'Scheduled Tribe', 'Teli', 'Other',
  ],
  'Punjab': [
    'Arora', 'Brahmin', 'Jat Sikh', 'Khatri', 'Mazhabi Sikh',
    'Ramgarhia', 'Ramdasia', 'Saini', 'Scheduled Caste', 'Other',
  ],
  'Rajasthan': [
    'Agarwal (Vaishya)', 'Brahmin (Dadhich)', 'Brahmin (Pushkarna)',
    'Gujar', 'Jat', 'Maheshwari', 'Mali', 'Meena (Tribal)', 'Meghwal',
    'Oswal Jain', 'Rajput (Chauhan)', 'Rajput (Rathore)', 'Rajput (Shekhawat)',
    'Yadav', 'Other',
  ],
  'Sikkim': ['Bhutia', 'Brahmin (Nepali)', 'Lepcha', 'Rai', 'Other'],
  'Tamil Nadu': [
    'Brahmin (Iyer)', 'Brahmin (Iyengar)', 'Chettiar (Nagarathar)',
    'Gounder (Kongu Vellala)', 'Mudaliar (Agamudayar)', 'Mudaliar (Arcot)',
    'Mudaliar (Saiva)', 'Nadar', 'Naicker', 'Pillai (Nair)', 'Pillai (Vellala)',
    'Thevar (Kallars)', 'Thevar (Mukkulathor)', 'Udayar', 'Vanniakula Kshatriya',
    'Vellalar (Saiva)', 'Other',
  ],
  'Telangana': [
    'Brahmin (Niyogi)', 'Brahmin (Vaidiki)', 'Goud', 'Kapu',
    'Kamma', 'Madiga', 'Mala', 'Munnuru Kapu',
    'Padmashali', 'Raju', 'Reddy', 'Yadava', 'Other',
  ],
  'Tripura': ['Bengali Hindu (Brahmin)', 'Debbarma (Tribal)', 'Jamatia', 'Reang', 'Other'],
  'Uttar Pradesh': [
    'Bhumihar', 'Brahmin (Gaur)', 'Brahmin (Kanyakubja)', 'Brahmin (Saryuparin)',
    'Chamar', 'Jat', 'Jatav', 'Kayastha', 'Koiri (Kushwaha)',
    'Kumhar', 'Kurmi', 'Lodha / Lodhi', 'Pasi', 'Rajput (Bisen)',
    'Rajput (Chauhan)', 'Rajput (Rathore)', 'Rajput (Sengar)', 'Teli',
    'Vaishya (Agarwal)', 'Vaishya (Gupta)', 'Yadav', 'Other',
  ],
  'Uttarakhand': [
    'Brahmin (Kumaoni)', 'Brahmin (Garhwali)', 'Rajput (Garhwali)',
    'Rajput (Kumaoni)', 'Scheduled Caste (Dom)', 'Other',
  ],
  'West Bengal': [
    'Baidya', 'Bengali Brahmin (Kulin)', 'Bengali Brahmin (Rarhi)',
    'Bene Israel', 'Goala (Yadav)', 'Kaibarta', 'Kayastha',
    'Mahishya', 'Namasudra', 'Rajbanshi', 'Sadgop', 'Sutradhar', 'Tili', 'Other',
  ],
};

const Map<String, List<String>> _subCastesByCaste = {
  'Brahmin': ['No Sub-caste', 'Any Sub-caste', 'Iyer', 'Iyengar', 'Namboodiri', 'Saraswat (GSB)', 'Deshastha', 'Konkanastha / Chitpavan', 'Karhade', 'Saryuparin', 'Kanyakubja', 'Gaur', 'Maithil', 'Other Brahmin'],
  'Rajput': ['No Sub-caste', 'Any Sub-caste', 'Chauhan', 'Rathore', 'Shekhawat', 'Sisodia', 'Tomara', 'Sengar', 'Bisen', 'Other Rajput'],
  'Kamma': ['No Sub-caste', 'Any Sub-caste', 'Kamma (AP)', 'Kamma (Telangana)', 'Other Kamma'],
  'Reddy': ['No Sub-caste', 'Any Sub-caste', 'Desai Reddy', 'Kapu Reddy', 'Mudiraj Reddy', 'Other Reddy'],
  'Maratha': ['No Sub-caste', 'Any Sub-caste', 'Chandraseniya (96 Kuli)', 'Kunbi Maratha', 'Other Maratha'],
  'Jat': ['No Sub-caste', 'Any Sub-caste', 'Ahirwal', 'Desh Haryana', 'UP Jat', 'Majha', 'Malwa', 'Doaba', 'Other Jat'],
  'Yadav / Ahir': ['No Sub-caste', 'Any Sub-caste', 'Ahir', 'Goala', 'Ghosi', 'Gwala', 'Rawat', 'Other Yadav'],
  'Patidar / Patel': ['No Sub-caste', 'Any Sub-caste', 'Kadva Patidar', 'Leuva Patidar'],
  'Kayastha': ['No Sub-caste', 'Any Sub-caste', 'Bengal Kayastha', 'UP Kayastha', 'Bihar Kayastha'],
  'Khatri': ['No Sub-caste', 'Any Sub-caste', 'Arora Khatri', 'Kapoor', 'Mehra', 'Sethi', 'Suri', 'Tandon'],
  'Vokkaliga / Gowda': ['No Sub-caste', 'Any Sub-caste', 'Gangadikara', 'Morasu', 'Okkaliga Gowda'],
  'Nair': ['No Sub-caste', 'Any Sub-caste', 'Kiriyathil Nair', 'Kaduppattan Nair', 'Kizhakke Nair'],
  'Ezhava / Thiyya': ['No Sub-caste', 'Any Sub-caste', 'Ezhava (Kerala)', 'Thiyya (Malabar)'],
};

const Map<String, List<String>> _subReligionByReligion = {
  'Hindu': ['Any Sub-religion', 'No Sub-religion', 'Shaiva', 'Vaishnava', 'Shakta', 'Smartha', 'Arya Samaj', 'Brahmo Samaj', 'ISKCON / Vaishnava', 'Lingayat', 'Swaminarayan', 'Other Hindu'],
  'Muslim': ['Any Sub-religion', 'No Sub-religion', 'Sunni (Hanafi)', "Sunni (Shafi'i)", 'Sunni (Maliki)', 'Shia (Ithna Ashari / Twelver)', 'Shia (Ismaili)', 'Bohra (Dawoodi)', 'Bohra (Sulaimani)', 'Ahmadiyya', 'Sufi', 'Other Muslim'],
  'Christian': ['Any Sub-religion', 'No Sub-religion', 'Catholic (Roman)', 'Catholic (Syro-Malabar)', 'Catholic (Syro-Malankara)', 'Catholic (Latin)', 'Church of South India (CSI)', 'Church of North India (CNI)', 'Mar Thoma Syrian', 'Jacobite Syrian Orthodox', 'Malankara Orthodox', 'Pentecostal', 'Baptist', 'Methodist', 'Lutheran', 'Salvation Army', 'Other Christian'],
  'Sikh': ['Any Sub-religion', 'No Sub-religion', 'Keshdhari', 'Sahajdhari', 'Nihang', 'Namdhari', 'Nirankari (Sant Nirankari)', 'Ravidasia', 'Other Sikh'],
  'Jain': ['Any Sub-religion', 'No Sub-religion', 'Digambara', 'Shvetambara (Murtipujak)', 'Shvetambara (Sthanakvasi)', 'Shvetambara (Terapanthi)', 'Other Jain'],
  'Buddhist': ['Any Sub-religion', 'No Sub-religion', 'Theravada', 'Mahayana (Zen)', 'Mahayana (Pure Land)', 'Vajrayana (Tibetan)', 'Ambedkarite / Navayana', 'Other Buddhist'],
  'Parsi / Zoroastrian': ['Any Sub-religion', 'No Sub-religion', 'Shehenshahi', 'Kadimi', 'Fasli', 'Other Zoroastrian'],
};

const List<String> _relStatusList = [
  'Single', 'Separated', 'Divorced', 'Widowed', 'Prefer not to say',
];

const List<String> _lifestyleOptions = ['Never', 'Occasionally', 'Often', 'Always', 'Prefer not to say'];
const List<String> _workoutOptions = ['Never', 'Sometimes', 'Regularly', 'Daily', 'Prefer not to say'];
const List<String> _petsOptions = ['Dogs', 'Cats', 'Birds', 'Reptiles', 'None', 'Other'];
const List<String> _childrenOptions = ['Have & want more', 'Have, no more', "Don't have, want", "Don't want", 'Not sure'];
const List<String> _dietOptions = ['Vegetarian', 'Non-Vegetarian', 'Vegan', 'Eggetarian', 'Jain', 'Other'];

// ─── Zodiac helper ────────────────────────────────────────────────────────────
String _zodiac(DateTime d) {
  final m = d.month, day = d.day;
  if ((m == 3 && day >= 21) || (m == 4 && day <= 19)) return 'Aries';
  if ((m == 4 && day >= 20) || (m == 5 && day <= 20)) return 'Taurus';
  if ((m == 5 && day >= 21) || (m == 6 && day <= 20)) return 'Gemini';
  if ((m == 6 && day >= 21) || (m == 7 && day <= 22)) return 'Cancer';
  if ((m == 7 && day >= 23) || (m == 8 && day <= 22)) return 'Leo';
  if ((m == 8 && day >= 23) || (m == 9 && day <= 22)) return 'Virgo';
  if ((m == 9 && day >= 23) || (m == 10 && day <= 22)) return 'Libra';
  if ((m == 10 && day >= 23) || (m == 11 && day <= 21)) return 'Scorpio';
  if ((m == 11 && day >= 22) || (m == 12 && day <= 21)) return 'Sagittarius';
  if ((m == 12 && day >= 22) || (m == 1 && day <= 19)) return 'Capricorn';
  if ((m == 1 && day >= 20) || (m == 2 && day <= 18)) return 'Aquarius';
  return 'Pisces';
}

int _ageFromDob(DateTime dob) {
  final now = DateTime.now();
  int age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
  return age;
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const int _totalSteps = 8;

  final List<String> _stepTitles = const [
    "What's your name?",
    'Tell us about yourself',
    'What are you looking for?',
    'Your background',
    'Your interests',
    'Your lifestyle',
    'Add your photos',
    'Verify your identity',
  ];

  final List<String> _stepDescriptions = const [
    "This is how you'll appear to matches",
    'Help us find your perfect match',
    'Be honest — it helps us match better',
    'Optional, but makes your profile stand out',
    'Show your personality',
    'Optional lifestyle details',
    'Profiles with photos get 10× more views',
    'A quick selfie to get verified (optional)',
  ];

  int _step = 0;

  // Step 0 — Name
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill name from Google account if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final googleName = context.read<AuthProvider>().pendingGoogleName;
      if (googleName != null && googleName.isNotEmpty) {
        _nameCtrl.text = googleName;
        context.read<AuthProvider>().clearPendingGoogleName();
      }
    });
  }

  // Step 1 — About / Location
  DateTime? _dob;
  String? _gender;
  String? _country;
  String? _state;
  String? _city;
  bool _isIndia = false;
  final _cityCtrl = TextEditingController();

  // Step 2 — Looking for
  String? _preferredGender;
  String? _goal;

  // Step 3 — Background
  String? _relStatus;
  String? _education;
  final _collegeCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _workplaceCtrl = TextEditingController();
  String? _religion;
  // Serious Matrimony extra fields
  String? _caste;
  String? _subCaste;
  String? _subReligion;
  String? _annualIncome;
  final _casteOtherCtrl = TextEditingController();

  // Step 4 — Interests
  final Set<String> _hobbies = {};
  final _heightCtrl = TextEditingController();
  final List<String> _selectedLanguages = [];
  final _bioCtrl = TextEditingController();

  // Step 5 — Lifestyle
  String? _drinking;
  String? _smoking;
  String? _workout;
  String? _pets;
  String? _children;
  String? _diet;
  final _firstDateCtrl = TextEditingController();

  // Step 6 — Photos
  final List<_Photo> _photos = [];

  // Step 7 — Selfie
  File? _selfie;

  bool _submitting = false;
  String? _error;

  final _picker = ImagePicker();
  static const _allowedExts = {'jpg', 'jpeg', 'png', 'webp'};

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _next() {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      if (_step < _totalSteps - 1) _step++;
    });
  }

  void _back() {
    if (_step > 0) setState(() { _step--; _error = null; });
  }

  void _skip() {
    setState(() { _error = null; _step++; });
  }

  String? _validate() {
    switch (_step) {
      case 0:
        if (_nameCtrl.text.trim().length < 2) return 'Please enter your name (at least 2 characters)';
        break;
      case 1:
        if (_dob == null) return 'Please select your date of birth';
        if (_ageFromDob(_dob!) < 18) return 'You must be at least 18 years old';
        if (_gender == null) return 'Please select your gender';
        if (_country == null) return 'Please select your country';
        if (_isIndia && _state == null) return 'Please select your state';
        if (_isIndia && _city == null) return 'Please select your city';
        if (!_isIndia && _cityCtrl.text.trim().isEmpty) return 'Please enter your city';
        break;
      case 2:
        if (_preferredGender == null) return 'Please select who you want to match with';
        if (_goal == null) return 'Please select your relationship goal';
        break;
      case 3:
        if (_relStatus == null) return 'Please select your relationship status';
        break;
      case 6:
        if (_photos.isEmpty) return 'Please add at least one photo';
        break;
      case 7:
        return null; // selfie optional
    }
    return null;
  }

  String _dobFormatted() {
    if (_dob == null) return '';
    return '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}';
  }

  // ── Date picker ─────────────────────────────────────────────────────────────
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 22),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 18),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFFF4E8A)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  // ── Image pickers ────────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    if (_photos.length >= 6) return;
    try {
      final xfile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (xfile == null || !mounted) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: xfile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: const Color(0xFF0D0D1A),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFFF4E8A),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Photo', minimumAspectRatio: 1.0),
          WebUiSettings(context: context),
        ],
      );
      if (cropped == null || !mounted) return;

      final bytes = await cropped.readAsBytes();
      final isMain = _photos.isEmpty;
      final photo = _Photo(bytes: bytes, uploading: true);
      setState(() => _photos.add(photo));

      // Upload immediately after crop
      try {
        final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final result = await ApiService.uploadImageBytes(bytes, filename, isMain: isMain);
        final url = result['image_url'] as String? ?? '';
        if (mounted) setState(() {
          photo.uploading = false;
          photo.uploaded = url.isNotEmpty;
          photo.url = url.isNotEmpty ? url : null;
        });
      } catch (_) {
        if (mounted) setState(() => photo.uploading = false);
      }
    } catch (_) {
      // Picker or cropper was cancelled or failed — nothing to do
    }
  }

  Future<void> _pickSelfie() async {
    try {
      final xfile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (xfile == null || !mounted) return;
      final ext = xfile.path.split('.').last.toLowerCase();
      if (!_allowedExts.contains(ext)) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text('Invalid file type', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Only JPEG, PNG, and WebP images are allowed.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Color(0xFFFF4E8A))),
              ),
            ],
          ),
        );
        return;
      }
      setState(() => _selfie = File(xfile.path));
    } catch (_) {
      // Camera access denied or cancelled — nothing to do
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      // Photos are uploaded immediately after crop — use stored URLs
      if (_photos.any((p) => p.uploading)) {
        setState(() { _error = 'Please wait for all photos to finish uploading'; _submitting = false; });
        return;
      }
      final photoUrls = _photos.where((p) => p.url != null).map((p) => p.url!).toList();

      // Upload selfie if provided
      String? selfieUrl;
      if (_selfie != null) {
        final result = await ApiService.uploadVerificationSelfie(_selfie!);
        selfieUrl = result['verification_image_url'] as String?;
      }

      final isMatrimony = _goal == 'Serious Matrimony';
      final goalApiValue = _goalApiValues[_goal] ?? _goal;
      final incomeApiValue = _annualIncome != null ? (_incomeApiValues[_annualIncome] ?? _annualIncome) : null;
      final casteValue = _caste == 'Other'
          ? (_casteOtherCtrl.text.trim().isEmpty ? null : _casteOtherCtrl.text.trim())
          : _caste;

      // Map gender
      String? genderApiValue;
      if (_gender == 'Male') {
        genderApiValue = 'male';
      } else if (_gender == 'Female') {
        genderApiValue = 'female';
      } else if (_gender == 'Non-binary') {
        genderApiValue = 'non_binary';
      } else if (_gender == 'Other') {
        genderApiValue = 'prefer_not_to_say';
      } else {
        genderApiValue = _gender;
      }

      // Map preferred gender
      String? preferredGenderApiValue;
      if (_preferredGender == 'Men') {
        preferredGenderApiValue = 'male';
      } else if (_preferredGender == 'Women') {
        preferredGenderApiValue = 'female';
      } else if (_preferredGender == 'Everyone') {
        preferredGenderApiValue = 'non_binary';
      } else {
        preferredGenderApiValue = _preferredGender;
      }

      // Map relationship status
      String? relStatusApiValue;
      if (_relStatus == 'Single') {
        relStatusApiValue = 'single';
      } else if (_relStatus == 'Separated') {
        relStatusApiValue = 'separated';
      } else if (_relStatus == 'Divorced') {
        relStatusApiValue = 'divorced';
      } else if (_relStatus == 'Widowed') {
        relStatusApiValue = 'widowed';
      }

      // Map education level
      String? educationApiValue;
      if (_education == 'High School') {
        educationApiValue = 'high_school';
      } else if (_education == 'Diploma') {
        educationApiValue = 'diploma';
      } else if (_education == "Bachelor's") {
        educationApiValue = 'bachelors';
      } else if (_education == "Master's") {
        educationApiValue = 'masters';
      } else if (_education == 'PhD') {
        educationApiValue = 'phd';
      } else if (_education == 'Other') {
        educationApiValue = 'other';
      } else {
        educationApiValue = _education;
      }

      // Map height to integer height_cm
      int? heightCmValue;
      if (_heightCtrl.text.trim().isNotEmpty) {
        heightCmValue = int.tryParse(_heightCtrl.text.trim());
      }

      // Map drinking
      String? drinkingApiValue;
      if (_drinking == 'Never') {
        drinkingApiValue = 'never';
      } else if (_drinking == 'Occasionally') {
        drinkingApiValue = 'socially';
      } else if (_drinking == 'Often') {
        drinkingApiValue = 'often';
      } else if (_drinking == 'Always') {
        drinkingApiValue = 'often';
      } else if (_drinking == 'Prefer not to say') {
        drinkingApiValue = 'prefer_not_to_say';
      }

      // Map smoking
      String? smokingApiValue;
      if (_smoking == 'Never') {
        smokingApiValue = 'never';
      } else if (_smoking == 'Occasionally') {
        smokingApiValue = 'socially';
      } else if (_smoking == 'Often') {
        smokingApiValue = 'regularly';
      } else if (_smoking == 'Always') {
        smokingApiValue = 'regularly';
      } else if (_smoking == 'Prefer not to say') {
        smokingApiValue = 'prefer_not_to_say';
      }

      // Map workout
      String? workoutApiValue;
      if (_workout == 'Never') {
        workoutApiValue = 'never';
      } else if (_workout == 'Sometimes') {
        workoutApiValue = 'sometimes';
      } else if (_workout == 'Regularly') {
        workoutApiValue = 'regularly';
      } else if (_workout == 'Daily') {
        workoutApiValue = 'daily';
      }

      // Map pets
      String? petsApiValue;
      if (_pets == 'Dogs') {
        petsApiValue = 'dog';
      } else if (_pets == 'Cats') {
        petsApiValue = 'cat';
      } else if (_pets == 'Birds') {
        petsApiValue = 'other';
      } else if (_pets == 'Reptiles') {
        petsApiValue = 'other';
      } else if (_pets == 'None') {
        petsApiValue = 'none';
      } else if (_pets == 'Other') {
        petsApiValue = 'other';
      }

      // Map children
      String? childrenApiValue;
      if (_children == 'Have & want more') {
        childrenApiValue = 'have_and_want_more';
      } else if (_children == 'Have, no more') {
        childrenApiValue = 'have_and_dont_want_more';
      } else if (_children == "Don't have, want") {
        childrenApiValue = 'want';
      } else if (_children == "Don't want") {
        childrenApiValue = 'dont_want';
      } else if (_children == 'Not sure') {
        childrenApiValue = 'unsure';
      }

      // Map diet
      String? dietApiValue;
      if (_diet == 'Vegetarian') {
        dietApiValue = 'vegetarian';
      } else if (_diet == 'Non-Vegetarian') {
        dietApiValue = 'non_vegetarian';
      } else if (_diet == 'Vegan') {
        dietApiValue = 'vegan';
      } else if (_diet == 'Eggetarian') {
        dietApiValue = 'eggetarian';
      } else if (_diet == 'Jain') {
        dietApiValue = 'jain';
      } else if (_diet == 'Other') {
        dietApiValue = 'other';
      }

      // Build payload
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'age': _ageFromDob(_dob!),
        'date_of_birth': _dob!.toIso8601String().split('T').first,
        'gender': genderApiValue,
        'preferred_gender': preferredGenderApiValue,
        'country': _country,
        'state': _isIndia ? _state : null,
        'city': _isIndia ? _city : _cityCtrl.text.trim(),
        'relationship_goal': goalApiValue,
        'relationship_status': relStatusApiValue,
        'education_level': educationApiValue,
        'college_university': _collegeCtrl.text.trim().isEmpty ? null : _collegeCtrl.text.trim(),
        'occupation': _occupationCtrl.text.trim().isEmpty ? null : _occupationCtrl.text.trim(),
        'workplace': _workplaceCtrl.text.trim().isEmpty ? null : _workplaceCtrl.text.trim(),
        'religion': _religion,
        'hobbies': _hobbies.toList(),
        'height_cm': heightCmValue,
        'languages': _selectedLanguages,
        'first_date_idea': _firstDateCtrl.text.trim().isEmpty ? null : _firstDateCtrl.text.trim(),
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        'drinking': drinkingApiValue,
        'smoking': smokingApiValue,
        'workout': workoutApiValue,
        'pets': petsApiValue,
        'children': childrenApiValue,
        'diet': dietApiValue,
        'zodiac_sign': _dob != null ? _zodiac(_dob!) : null,
        'photos': photoUrls,
        if (selfieUrl != null) 'selfie_url': selfieUrl,
        if (isMatrimony && casteValue != null) 'caste': casteValue,
        if (isMatrimony && _subCaste != null) 'sub_caste': _subCaste,
        if (isMatrimony && _subReligion != null) 'sub_religion': _subReligion,
        if (isMatrimony && incomeApiValue != null) 'annual_income': incomeApiValue,
      };

      await ApiService.completeProfile(payload);
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() { _error = e.toString(); _submitting = false; });
    }
  }

  // ─── Build helpers ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLast = _step == _totalSteps - 1;
    final canSkip = _step >= 3 && _step <= 5;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Stack(
          children: [
            const _DarkGlowBg(),
            const _SlantedScrollingBackground(),
            // Soft background blur so the slanted scrolling cards are dreamlike and professional
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                child: Container(
                  color: const Color(0xFF0D0D1A).withOpacity(0.25),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepTitle(),
                          const SizedBox(height: 24),
                          if (_error != null) _ErrorBanner(message: _error!),
                          _GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                              child: _buildStep(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(isLast: isLast, canSkip: canSkip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              if (_step > 0)
                GestureDetector(
                  onTap: _back,
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
                )
              else
                const SizedBox(width: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _totalSteps,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFF4E8A)),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_step + 1}/$_totalSteps',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _stepTitles[_step],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _stepDescriptions[_step],
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFooter({required bool isLast, required bool canSkip}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
        ),
      ),
      child: Row(
        children: [
          if (canSkip)
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : _skip,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Skip', style: TextStyle(color: Colors.white60)),
              ),
            ),
          if (canSkip) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _submitting ? null : (isLast ? _submit : _next),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4E8A), Color(0xFFFF6B35)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: Color(0x55FF4E8A), blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isLast ? 'Complete Profile' : 'Continue',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step builders ───────────────────────────────────────────────────────────
  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildName();
      case 1: return _buildAbout();
      case 2: return _buildLookingFor();
      case 3: return _buildBackground();
      case 4: return _buildInterests();
      case 5: return _buildLifestyle();
      case 6: return _buildPhotos();
      case 7: return _buildSelfie();
      default: return const SizedBox.shrink();
    }
  }

  // Step 0 ── Name
  Widget _buildName() {
    return _Input(
      controller: _nameCtrl,
      label: 'First name',
      hint: 'E.g. Arjun',
      autofocus: true,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'))],
    );
  }

  // Step 1 ── About / Location
  Widget _buildAbout() {
    return Column(
      children: [
        // DOB
        GestureDetector(
          onTap: _pickDob,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, color: Colors.white54, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _dob == null
                        ? 'Date of birth'
                        : '${_dobFormatted()}  (${_ageFromDob(_dob!)} yrs, ${_zodiac(_dob!)})',
                    style: TextStyle(
                      color: _dob == null ? Colors.white38 : Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _DropdownField(
          value: _gender,
          hint: 'Gender',
          icon: Icons.person_outline,
          items: const ['Male', 'Female', 'Non-binary', 'Other'],
          onChanged: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: 14),
        _DropdownField(
          value: _country,
          hint: 'Country',
          icon: Icons.public,
          items: _countries,
          onChanged: (v) {
            setState(() {
              _country = v;
              _isIndia = v == 'India';
              _state = null;
              _city = null;
              _cityCtrl.clear();
            });
          },
        ),
        if (_isIndia) ...[
          const SizedBox(height: 14),
          _DropdownField(
            value: _state,
            hint: 'State',
            icon: Icons.location_city_outlined,
            items: _indiaCities.keys.toList(),
            onChanged: (v) => setState(() { _state = v; _city = null; }),
          ),
        ],
        if (_isIndia && _state != null) ...[
          const SizedBox(height: 14),
          _DropdownField(
            value: _city,
            hint: 'City',
            icon: Icons.place_outlined,
            items: _indiaCities[_state!] ?? [],
            onChanged: (v) => setState(() => _city = v),
          ),
        ],
        if (!_isIndia && _country != null) ...[
          const SizedBox(height: 14),
          _Input(
            controller: _cityCtrl,
            label: 'City',
            hint: 'Your city',
          ),
        ],
      ],
    );
  }

  // Step 2 ── Looking for
  Widget _buildLookingFor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DropdownField(
          value: _preferredGender,
          hint: 'Interested in',
          icon: Icons.favorite_border,
          items: const ['Men', 'Women', 'Everyone'],
          onChanged: (v) => setState(() => _preferredGender = v),
        ),
        const SizedBox(height: 14),
        const _SectionDivider(label: 'Relationship goal'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _goalList.map((g) => _ChipSelect(
            label: g,
            selected: _goal == g,
            onTap: () => setState(() => _goal = g),
          )).toList(),
        ),
      ],
    );
  }

  // Step 3 ── Background
  Widget _buildBackground() {
    final isMatrimony = _goal == 'Serious Matrimony';

    // State-based caste list — special options first, then state communities
    final stateCommunities = _state != null ? (_stateCastes[_state] ?? ['Other']) : ['Other'];
    final casteItems = ['No Caste', 'Any Caste', ...stateCommunities];

    final subCastesForCaste = (_caste != null && !_specialCasteOptions.contains(_caste) && _caste != 'Other')
        ? (_subCastesByCaste[_caste] ?? <String>[])
        : <String>[];
    final subReligionsForReligion = _religion != null
        ? (_subReligionByReligion[_religion] ?? <String>[])
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMatrimony) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x1A8B5CF6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x408B5CF6)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🕌', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Serious Matrimony pool',
                          style: TextStyle(color: Color(0xFFA78BFA), fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text(
                        "You'll only be seen by others seriously looking for marriage. Caste, religion & income details help us find compatible matches.",
                        style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const _SectionDivider(label: 'Relationship status'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _relStatusList.map((r) => _ChipSelect(
            label: r,
            selected: _relStatus == r,
            onTap: () => setState(() => _relStatus = r),
          )).toList(),
        ),
        const SizedBox(height: 16),
        _DropdownField(
          value: _education,
          hint: 'Education level',
          icon: Icons.school_outlined,
          items: _educationList,
          onChanged: (v) => setState(() => _education = v),
        ),
        const SizedBox(height: 14),
        _Input(controller: _collegeCtrl, label: 'College / University', hint: 'E.g. Delhi University'),
        const SizedBox(height: 14),
        _Input(controller: _occupationCtrl, label: 'Occupation', hint: 'E.g. Software Engineer'),
        const SizedBox(height: 14),
        _Input(controller: _workplaceCtrl, label: 'Workplace / Company', hint: 'E.g. Google'),
        const SizedBox(height: 14),
        _DropdownField(
          value: _religion,
          hint: 'Religion',
          icon: Icons.temple_hindu_outlined,
          items: _religionList,
          onChanged: (v) => setState(() {
            _religion = v;
            _subReligion = null;
            _caste = null;
            _subCaste = null;
          }),
        ),
        // ── Serious Matrimony extra fields ─────────────────────────
        if (isMatrimony) ...[
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'These details are only shared with other Serious Matrimony profiles.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const SizedBox(height: 10),
          // Caste — filtered by user's selected state
          if (_state == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.white38, size: 16),
                SizedBox(width: 8),
                Text('Select your state above to see caste options',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ]),
            )
          else
            _DropdownField(
              value: casteItems.contains(_caste) ? _caste : null,
              hint: 'Caste',
              icon: Icons.groups_outlined,
              items: casteItems,
              onChanged: (v) => setState(() {
                _caste = v;
                _subCaste = null;
                _casteOtherCtrl.clear();
              }),
            ),
          // Sub-caste (only when caste is specific, not special/Other)
          if (_caste != null && !_specialCasteOptions.contains(_caste) && _caste != 'Other' && subCastesForCaste.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DropdownField(
              value: _subCaste,
              hint: 'Sub-caste',
              icon: Icons.group_outlined,
              items: subCastesForCaste,
              onChanged: (v) => setState(() => _subCaste = v),
            ),
          ],
          // Sub-religion
          if (_religion != null &&
              _religion != 'No Religion' &&
              _religion != 'Any Religion' &&
              subReligionsForReligion.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DropdownField(
              value: _subReligion,
              hint: 'Sub-religion / Sect',
              icon: Icons.account_balance_outlined,
              items: subReligionsForReligion,
              onChanged: (v) => setState(() => _subReligion = v),
            ),
          ],
          // Annual income
          const SizedBox(height: 14),
          _DropdownField(
            value: _annualIncome,
            hint: 'Annual income (optional)',
            icon: Icons.currency_rupee,
            items: _incomeList,
            onChanged: (v) => setState(() => _annualIncome = v),
          ),
        ],
      ],
    );
  }

  // Step 4 ── Interests
  Widget _buildInterests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Input(controller: _heightCtrl, label: 'Height (cm)', hint: 'E.g. 175',
            keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _showLanguagesSelect(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.translate, color: Colors.white54, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedLanguages.isEmpty
                        ? 'Languages spoken'
                        : _selectedLanguages.join(', '),
                    style: TextStyle(
                      color: _selectedLanguages.isEmpty ? Colors.white38 : Colors.white,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Input(controller: _bioCtrl, label: 'Bio', hint: 'Tell people about yourself...', maxLines: 3),
        const SizedBox(height: 16),
        const _SectionDivider(label: 'Hobbies & Interests'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _hobbiesList.map((h) => _ChipSelect(
            label: h,
            selected: _hobbies.contains(h),
            onTap: () => setState(() {
              if (_hobbies.contains(h)) _hobbies.remove(h); else _hobbies.add(h);
            }),
          )).toList(),
        ),
      ],
    );
  }

  // Step 5 ── Lifestyle
  Widget _buildLifestyle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LifestyleRow(
          label: '🍺 Drinking',
          value: _drinking,
          options: _lifestyleOptions,
          onChanged: (v) => setState(() => _drinking = v),
        ),
        const SizedBox(height: 14),
        _LifestyleRow(
          label: '🚬 Smoking',
          value: _smoking,
          options: _lifestyleOptions,
          onChanged: (v) => setState(() => _smoking = v),
        ),
        const SizedBox(height: 14),
        _LifestyleRow(
          label: '💪 Workout',
          value: _workout,
          options: _workoutOptions,
          onChanged: (v) => setState(() => _workout = v),
        ),
        const SizedBox(height: 14),
        _LifestyleRow(
          label: '🐾 Pets',
          value: _pets,
          options: _petsOptions,
          onChanged: (v) => setState(() => _pets = v),
        ),
        const SizedBox(height: 14),
        _LifestyleRow(
          label: '👶 Children',
          value: _children,
          options: _childrenOptions,
          onChanged: (v) => setState(() => _children = v),
        ),
        const SizedBox(height: 14),
        _LifestyleRow(
          label: '🥗 Diet',
          value: _diet,
          options: _dietOptions,
          onChanged: (v) => setState(() => _diet = v),
        ),
        const SizedBox(height: 14),
        _Input(
          controller: _firstDateCtrl,
          label: 'First date idea',
          hint: 'E.g. Coffee at a cozy café',
        ),
      ],
    );
  }

  // Step 6 ── Photos
  Widget _buildPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BulletRow(text: 'Add up to 6 photos — first photo is your main'),
        const _BulletRow(text: 'Crop each photo after selecting'),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: 6,
          itemBuilder: (ctx, i) {
            if (i < _photos.length) {
              final photo = _photos[i];
              return Stack(
                children: [
                  // Image preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      photo.bytes,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Upload spinner overlay
                  if (photo.uploading)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Colors.black54,
                          child: const Center(
                            child: SizedBox(
                              width: 28, height: 28,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // MAIN badge
                  if (i == 0)
                    Positioned(
                      bottom: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4E8A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Main',
                            style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                  // Green check when uploaded
                  if (photo.uploaded)
                    Positioned(
                      bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Color(0xFF16A34A), shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.white, size: 10),
                      ),
                    ),
                  // Remove button (hidden while uploading)
                  if (!photo.uploading)
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                ],
              );
            }
            return GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Center(
                  child: Icon(Icons.add_a_photo_outlined, color: Colors.white38, size: 28),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Step 7 ── Selfie
  Widget _buildSelfie() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BulletRow(text: 'A selfie helps us verify your identity'),
        const _BulletRow(text: 'This step is optional — you can do it later'),
        const _BulletRow(text: 'Verified users get a blue badge'),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: _pickSelfie,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selfie != null ? const Color(0xFFFF4E8A) : Colors.white24,
                  width: 2,
                ),
              ),
              child: _selfie != null
                  ? ClipOval(
                      child: Image.file(_selfie!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'Take selfie',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (_selfie != null) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _selfie = null),
              icon: const Icon(Icons.refresh, color: Color(0xFFFF4E8A), size: 18),
              label: const Text('Retake', style: TextStyle(color: Color(0xFFFF4E8A))),
            ),
          ),
        ],
      ],
    );
  }

  void _showLanguagesSelect(BuildContext context) {
    final localSelected = Set<String>.from(_selectedLanguages);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (stContext, setState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Select languages spoken', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _languagesList.length,
                  itemBuilder: (context, index) {
                    final lang = _languagesList[index];
                    final isSelected = localSelected.contains(lang);
                    return CheckboxListTile(
                      title: Text(lang, style: const TextStyle(color: Colors.white, fontSize: 15)),
                      value: isSelected,
                      activeColor: const Color(0xFFFF4E8A),
                      checkColor: Colors.white,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            localSelected.add(lang);
                          } else {
                            localSelected.remove(lang);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      this.setState(() {
                        _selectedLanguages.clear();
                        _selectedLanguages.addAll(localSelected);
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4E8A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _collegeCtrl.dispose();
    _occupationCtrl.dispose();
    _workplaceCtrl.dispose();
    _heightCtrl.dispose();
    _bioCtrl.dispose();
    _firstDateCtrl.dispose();
    _casteOtherCtrl.dispose();
    super.dispose();
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _DarkGlowBg extends StatelessWidget {
  const _DarkGlowBg();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.3, -0.6),
            radius: 1.2,
            colors: [Color(0x12FF4E8A), Color(0xFF0D0D1A)],
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: Colors.white12, thickness: 1)),
    ],
  );
}

class _BulletRow extends StatelessWidget {
  final String text;
  const _BulletRow({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: Color(0xFFFF4E8A), fontSize: 16)),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14))),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red.withOpacity(0.4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
      ],
    ),
  );
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool autofocus;
  final TextInputType? keyboardType;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;

  const _Input({
    required this.controller,
    required this.label,
    required this.hint,
    this.autofocus = false,
    this.keyboardType,
    this.maxLines = 1,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4E8A), width: 1.5),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E1E2E),
          hint: Row(children: [
            Icon(icon, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Text(hint, style: const TextStyle(color: Colors.white38, fontSize: 15)),
          ]),
          icon: const Icon(Icons.expand_more, color: Colors.white38),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ChipSelect extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipSelect({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF4E8A).withOpacity(0.2) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFF4E8A) : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFFF4E8A) : Colors.white70,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _LifestyleRow extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _LifestyleRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((o) => _ChipSelect(
            label: o,
            selected: value == o,
            onTap: () => onChanged(o),
          )).toList(),
        ),
      ],
    );
  }
}

// ─── Scrolling Slanted Background & Glassmorphic Widgets ───────────────────────

final List<Map<String, String>> _mockProfiles = const [
  {
    'name': 'Sofia',
    'age': '24',
    'image': 'assets/images/p1.jpg',
    'city': 'Delhi',
    'match': '98% Match',
  },
  {
    'name': 'Liam',
    'age': '27',
    'image': 'assets/images/p2.jpg',
    'city': 'Mumbai',
    'match': '95% Match',
  },
  {
    'name': 'Maya',
    'age': '23',
    'image': 'assets/images/p3.jpg',
    'city': 'Bengaluru',
    'match': '92% Match',
  },
  {
    'name': 'Aarav',
    'age': '26',
    'image': 'assets/images/p2.jpg',
    'city': 'Pune',
    'match': '89% Match',
  },
  {
    'name': 'Ananya',
    'age': '25',
    'image': 'assets/images/p1.jpg',
    'city': 'Hyderabad',
    'match': '96% Match',
  },
  {
    'name': 'Rohan',
    'age': '28',
    'image': 'assets/images/p2.jpg',
    'city': 'Noida',
    'match': '94% Match',
  },
  {
    'name': 'Diya',
    'age': '22',
    'image': 'assets/images/p3.jpg',
    'city': 'Kolkata',
    'match': '91% Match',
  },
];

class _BackgroundProfileCard extends StatelessWidget {
  final Map<String, String> profile;
  const _BackgroundProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Profile image
            Image.asset(
              profile['image']!,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF4E8A).withOpacity(0.4),
                      const Color(0xFFFF6B35).withOpacity(0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.person, color: Colors.white24, size: 40),
              ),
            ),
            // Bottom gradient overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Text details
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${profile['name']}, ${profile['age']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Color(0xFFFF4E8A), size: 10),
                      const SizedBox(width: 4),
                      Text(
                        profile['match'] ?? '90%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoScrollingRow extends StatefulWidget {
  final List<Widget> items;
  final double itemWidth;
  final bool reverse;
  final double speed;

  const _AutoScrollingRow({
    required this.items,
    required this.itemWidth,
    this.reverse = false,
    this.speed = 30.0,
  });

  @override
  State<_AutoScrollingRow> createState() => _AutoScrollingRowState();
}

class _AutoScrollingRowState extends State<_AutoScrollingRow> with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    final totalWidth = widget.items.length * widget.itemWidth;
    final durationSeconds = totalWidth / widget.speed;
    
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (durationSeconds * 1000).toInt()),
    )..addListener(() {
        if (mounted && _scrollController.hasClients) {
          try {
            final totalWidth = widget.items.length * widget.itemWidth;
            final value = _animationController.value;
            final offset = widget.reverse 
                ? (1.0 - value) * totalWidth 
                : value * totalWidth;
            _scrollController.jumpTo(offset);
          } catch (_) {}
        }
      });
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duplicated = [...widget.items, ...widget.items, ...widget.items];
    return SizedBox(
      height: 166,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: duplicated.length,
        itemBuilder: (context, index) {
          return duplicated[index];
        },
      ),
    );
  }
}

class _SlantedScrollingBackground extends StatelessWidget {
  const _SlantedScrollingBackground();

  @override
  Widget build(BuildContext context) {
    final row1Profiles = [
      _mockProfiles[0],
      _mockProfiles[1],
      _mockProfiles[2],
      _mockProfiles[3],
      _mockProfiles[4],
    ];
    final row2Profiles = [
      _mockProfiles[5],
      _mockProfiles[6],
      _mockProfiles[0],
      _mockProfiles[1],
      _mockProfiles[2],
    ];
    final row3Profiles = [
      _mockProfiles[3],
      _mockProfiles[4],
      _mockProfiles[5],
      _mockProfiles[6],
      _mockProfiles[0],
    ];

    return Positioned.fill(
      child: ClipRect(
        child: Opacity(
          opacity: 0.08,
          child: Transform.rotate(
            angle: -0.12,
            child: Transform.scale(
              scale: 1.3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AutoScrollingRow(
                    items: row1Profiles.map((p) => _BackgroundProfileCard(profile: p)).toList(),
                    itemWidth: 130.0,
                    reverse: true,
                    speed: 25.0,
                  ),
                  const SizedBox(height: 16),
                  _AutoScrollingRow(
                    items: row2Profiles.map((p) => _BackgroundProfileCard(profile: p)).toList(),
                    itemWidth: 130.0,
                    reverse: false,
                    speed: 18.0,
                  ),
                  const SizedBox(height: 16),
                  _AutoScrollingRow(
                    items: row3Profiles.map((p) => _BackgroundProfileCard(profile: p)).toList(),
                    itemWidth: 130.0,
                    reverse: true,
                    speed: 22.0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16162A).withOpacity(0.65),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
