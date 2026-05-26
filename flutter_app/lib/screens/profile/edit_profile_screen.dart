import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/compatibility_questions.dart';
import '../../utils/time_utils.dart';
import '../../widgets/compatibility_section.dart';
import 'profile_preview_screen.dart';

// ─── Constants for Dropdowns ──────────────────────────────────────────────────
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

const List<String> _hobbiesList = [
  'Reading', 'Travelling', 'Gaming', 'Cooking', 'Fitness', 'Photography',
  'Music', 'Dancing', 'Art', 'Movies', 'Yoga', 'Hiking', 'Writing',
  'Sports', 'Cycling', 'Swimming', 'Gardening', 'Meditation',
];

const List<String> _vibesList = [
  'Adventurous', 'Romantic', 'Ambitious', 'Chill', 'Creative',
  'Funny', 'Intellectual', 'Spontaneous', 'Spiritual', 'Foodie',
  'Night Owl', 'Early Bird', 'Introvert', 'Extrovert', 'Geeky', 'Mindful'
];

const Map<String, String> _vibesEmojis = {
  'Adventurous': '🌍',
  'Romantic': '💖',
  'Ambitious': '🚀',
  'Chill': '🌿',
  'Creative': '🎨',
  'Funny': '😂',
  'Intellectual': '🧠',
  'Spontaneous': '⚡',
  'Spiritual': '🕉️',
  'Foodie': '🍜',
  'Night Owl': '🌙',
  'Early Bird': '🌅',
  'Introvert': '🤫',
  'Extrovert': '🎉',
  'Geeky': '🤓',
  'Mindful': '🧘',
};

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

const List<String> _languagesList = [
  'English', 'Hindi', 'Bengali', 'Telugu', 'Marathi', 'Tamil', 'Urdu', 
  'Gujarati', 'Kannada', 'Malayalam', 'Odia', 'Punjabi', 'Assamese', 
  'Maithili', 'Sanskrit', 'Marwari', 'Bhojpuri', 'Spanish', 'French', 
  'German', 'Mandarin', 'Arabic', 'Russian', 'Portuguese', 'Japanese'
];

const List<String> _lifestyleOptions = ['Never', 'Occasionally', 'Often', 'Always', 'Prefer not to say'];
const List<String> _workoutOptions = ['Never', 'Sometimes', 'Regularly', 'Daily', 'Prefer not to say'];
const List<String> _petsOptions = ['Dogs', 'Cats', 'Birds', 'Reptiles', 'None', 'Other'];
const List<String> _childrenOptions = ['Have & want more', 'Have, no more', "Don't have, want", "Don't want", 'Not sure'];
const List<String> _dietOptions = ['Vegetarian', 'Non-Vegetarian', 'Vegan', 'Eggetarian', 'Jain', 'Other'];

String? _deriveStateFromCity(String? city) {
  if (city == null || city.isEmpty) return null;
  for (final entry in _indiaCities.entries) {
    if (entry.value.contains(city)) {
      return entry.key;
    }
  }
  return null;
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Track which imageId is currently uploading/deleting for per-slot spinner
  String? _busyId;
  // Track which empty slots are uploading (by slot index)
  final Set<int> _busySlots = {};

  bool get _saving => _busyId != null || _busySlots.isNotEmpty;

  /// Tap on EMPTY slot → pick + crop + upload
  Future<void> _pickPhoto(int slot) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null || !mounted) return;
      final cropped = await _cropImage(picked.path);
      if (cropped == null || !mounted) return;
      setState(() => _busySlots.add(slot));
      final bytes = await cropped.readAsBytes();
      final fn = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await ApiService.uploadImageBytes(bytes, fn, isMain: slot == 0);
      if (mounted) await context.read<AuthProvider>().refreshProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to upload photo. Please try again.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busySlots.remove(slot));
    }
  }

  /// Tap on EXISTING photo → show preview popup with Delete + Edit
  Future<void> _showPhotoOptions(
      BuildContext context, String imageUrl, String imageId, bool isMain) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _PhotoOptionsDialog(
        imageUrl: imageUrl,
        isMain: isMain,
        onEdit: () async {
          Navigator.pop(context);
          await _editPhoto(imageId, isMain);
        },
        onDelete: () {
          Navigator.pop(context);
          _deletePhoto(imageId);
        },
        onSetMain: isMain ? null : () {
          Navigator.pop(context);
          _setMain(imageId);
        },
      ),
    );
  }

  /// Edit = pick new image, crop, upload (replaces old one)
  Future<void> _editPhoto(String imageId, bool isMain) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null || !mounted) return;
      final cropped = await _cropImage(picked.path);
      if (cropped == null || !mounted) return;
      setState(() => _busyId = imageId);
      await ApiService.deletePhoto(imageId);
      final bytes = await cropped.readAsBytes();
      final fn = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await ApiService.uploadImageBytes(bytes, fn, isMain: isMain);
      if (mounted) await context.read<AuthProvider>().refreshProfile();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update photo. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<CroppedFile?> _cropImage(String sourcePath) async {
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Photo',
          toolbarColor: const Color(0xFF0D0D1A),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFFEC4899),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          showCropGrid: true,
        ),
        IOSUiSettings(title: 'Edit Photo', minimumAspectRatio: 1.0, rotateButtonsHidden: false),
        WebUiSettings(context: context),
      ],
    );
  }

  Future<void> _setMain(String imageId) async {
    setState(() => _busyId = imageId);
    try {
      await ApiService.setMainPhoto(imageId);
      if (mounted) await context.read<AuthProvider>().refreshProfile();
    } catch (_) {} finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deletePhoto(String imageId) async {
    setState(() => _busyId = imageId);
    try {
      await ApiService.deletePhoto(imageId);
      if (mounted) await context.read<AuthProvider>().refreshProfile();
    } catch (_) {} finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _pickCoverPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _busyId = 'cover_pick');
    try {
      final bytes = await picked.readAsBytes();
      final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await ApiService.uploadCoverPhoto(bytes, filename);
      if (mounted) await context.read<AuthProvider>().refreshProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deleteCoverPhoto() async {
    setState(() => _busyId = 'cover_delete');
    try {
      await ApiService.deleteCoverPhoto();
      if (mounted) await context.read<AuthProvider>().refreshProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18, color: AppTheme.textSecondary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit profile',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context))),
        actions: [
          if (profile != null)
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ProfilePreviewScreen(profile: profile))),
              child: const Text('Preview',
                  style: TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // ── Photos ──────────────────────────────────────────────
                _SectionCard(
                  title: 'Photos',
                  child: _PhotoGrid(
                    profile: profile,
                    onPickPhoto: _pickPhoto,
                    onShowOptions: _showPhotoOptions,
                    busyId: _busyId,
                    busySlots: _busySlots,
                  ),
                ),
                const SizedBox(height: 14),

                // ── Cover photo ─────────────────────────────────────────
                _SectionCard(
                  title: 'Cover photo',
                  child: _CoverPhotoRow(
                    coverUrl: profile.coverPhotoUrl,
                    saving: _saving,
                    onPick: _pickCoverPhoto,
                    onDelete: _deleteCoverPhoto,
                  ),
                ),
                const SizedBox(height: 14),

                // ── Basic details ────────────────────────────────────────
                _SectionCard(
                  title: 'Basic details',
                  editLabel: 'Edit',
                  onEdit: () => _showBasicEdit(context, profile),
                  child: _BasicDetails(profile: profile),
                ),
                const SizedBox(height: 14),

                // ── Serious Matrimony details ────────────────────────────
                if (profile.relationshipGoal == 'serious_marriage') ...[
                  _SectionCard(
                    title: 'Serious Matrimony details',
                    editLabel: 'Edit',
                    onEdit: () => _showMatrimonyEdit(context, profile),
                    child: _MatrimonyDetails(profile: profile),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── About me ─────────────────────────────────────────────
                _SectionCard(
                  title: 'Vibe quote',
                  editLabel: profile.bio?.isNotEmpty == true ? 'Edit' : null,
                  child: profile.bio?.isNotEmpty == true
                      ? Text(profile.bio!,
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(context), height: 1.6))
                      : _AddButton('Add vibe quote', () => _showBioEdit(context, profile)),
                ),
                const SizedBox(height: 14),

                // ── Hobbies ───────────────────────────────────────────────
                _SectionCard(
                  title: 'Hobbies',
                  editLabel: 'Edit',
                  onEdit: () => _showHobbiesEdit(context, profile),
                  child: profile.hobbies.isNotEmpty
                      ? Wrap(spacing: 8, runSpacing: 8,
                          children: profile.hobbies.map((h) => _Chip(h)).toList())
                      : _AddButton('Add hobbies', () => _showHobbiesEdit(context, profile)),
                ),
                const SizedBox(height: 14),

                // ── Vibe adjectives ───────────────────────────────────────
                _SectionCard(
                  title: 'Vibe adjectives',
                  editLabel: 'Edit',
                  onEdit: () => _showVibesEdit(context, profile),
                  child: profile.vibes.isNotEmpty
                      ? Wrap(spacing: 8, runSpacing: 8,
                          children: profile.vibes.map((v) => _Chip(v)).toList())
                      : _AddButton('Add vibe adjectives', () => _showVibesEdit(context, profile)),
                ),
                const SizedBox(height: 14),

                // ── Lifestyle alignment ───────────────────────────────────
                _SectionCard(
                  title: 'Lifestyle alignment',
                  editLabel: 'Edit',
                  onEdit: () => _showLifestyleEdit(context, profile),
                  child: _LifestyleChips(profile: profile),
                ),
                const SizedBox(height: 14),

                // ── Compatibility questions ───────────────────────────────
                CompatibilityEditSection(
                  title: compatibilitySectionTitle(profile.relationshipGoal),
                  answers: profile.compatibilityAnswers,
                  onEdit: () => _showCompatibilitySheet(context, profile),
                ),
              ],
            ),
    );
  }

  bool _hasLifestyle(ProfileModel p) =>
      p.drinking != null || p.smoking != null || p.workout != null ||
      p.pets != null || p.children != null || p.diet != null;

  void _showCompatibilitySheet(BuildContext context, ProfileModel profile) {
    final questions = questionsForGoal(profile.relationshipGoal);
    // Pre-fill existing answers
    final Map<String, String> selected = {
      for (final a in profile.compatibilityAnswers)
        if (a['question'] != null && a['answer'] != null)
          a['question'] as String: a['answer'] as String,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CompatibilitySheet(
        questions: questions,
        initial: selected,
        onSave: (answers) async {
          try {
            await ApiService.updateProfile({'compatibility_answers': answers});
            await context.read<AuthProvider>().refreshProfile();
          } catch (_) {}
        },
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required BuildContext context,
    required T? value,
    required String label,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T)? itemLabel,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: AppTheme.cardBg(context),
      style: TextStyle(fontSize: 14, color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textFaint(context), fontSize: 13),
        filled: true,
        fillColor: AppTheme.inputBg(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryPink, width: 2),
        ),
      ),
      items: items.map((item) {
        final labelText = itemLabel != null ? itemLabel(item) : item.toString();
        return DropdownMenuItem<T>(
          value: item,
          child: Text(labelText),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  void _showBasicEdit(BuildContext context, ProfileModel profile) {
    final nameCtrl = TextEditingController(text: profile.name ?? '');
    String? localGender = profile.gender;
    String? localCountry = profile.country ?? 'India';
    String? localState = _deriveStateFromCity(profile.city);
    String? localCity = profile.city;
    String? localReligion = profile.religion;
    String? localEducation;
    if (profile.education == 'high_school') {
      localEducation = 'High School';
    } else if (profile.education == 'diploma') {
      localEducation = 'Diploma';
    } else if (profile.education == 'bachelors') {
      localEducation = "Bachelor's";
    } else if (profile.education == 'masters') {
      localEducation = "Master's";
    } else if (profile.education == 'phd') {
      localEducation = 'PhD';
    } else if (profile.education == 'other') {
      localEducation = 'Other';
    } else {
      localEducation = profile.education;
    }
    String? localGoal = profile.relationshipGoal;
    String? localStatus;
    if (profile.relationshipStatus == 'single') {
      localStatus = 'Single';
    } else if (profile.relationshipStatus == 'separated') {
      localStatus = 'Separated';
    } else if (profile.relationshipStatus == 'divorced') {
      localStatus = 'Divorced';
    } else if (profile.relationshipStatus == 'widowed') {
      localStatus = 'Widowed';
    } else {
      localStatus = profile.relationshipStatus;
    }
    
    final cityCtrl = TextEditingController(text: profile.city ?? '');
    final occupationCtrl = TextEditingController(text: profile.occupation ?? '');
    final collegeCtrl = TextEditingController(text: profile.collegeUniversity ?? '');
    final workplaceCtrl = TextEditingController(text: profile.workplace ?? '');
    final heightCtrl = TextEditingController(text: profile.heightCm != null ? profile.heightCm.toString() : '');
    List<String> localLanguages = List<String>.from(profile.languages);
    final phoneCtrl = TextEditingController(text: profile.phoneNumber ?? '');
    
    DateTime? localDob = profile.dateOfBirth != null ? DateTime.tryParse(profile.dateOfBirth!) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (stContext, setState) {
          final isIndia = localCountry == 'India';
          final states = _indiaCities.keys.toList();
          final cities = localState != null ? (_indiaCities[localState] ?? <String>[]) : <String>[];

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 8),
                  child: _sheetHandle(),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    children: [
                      Text(
                        'Basic details',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context)),
                      ),
                      const SizedBox(height: 20),
                      _sheetField(nameCtrl, 'Display name', context),
                      const SizedBox(height: 14),
                      
                      _buildDropdownField<String>(
                        context: context,
                        value: localGender != null && ['male', 'female', 'non_binary', 'prefer_not_to_say'].contains(localGender) ? localGender : null,
                        label: 'Gender',
                        items: ['male', 'female', 'non_binary', 'prefer_not_to_say'],
                        itemLabel: (v) {
                          if (v == 'male') return 'Male';
                          if (v == 'female') return 'Female';
                          if (v == 'non_binary') return 'Non-binary';
                          return 'Prefer not to say';
                        },
                        onChanged: (v) => setState(() => localGender = v),
                      ),
                      const SizedBox(height: 14),

                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: localDob ?? DateTime(1998, 1, 1),
                            firstDate: DateTime(1950),
                            lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                            builder: (context, child) {
                              final isDark = AppTheme.isDark(context);
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: isDark
                                      ? const ColorScheme.dark(
                                          primary: AppTheme.primaryPink,
                                          onPrimary: Colors.white,
                                          surface: Color(0xFF16162A),
                                          onSurface: Color(0xFFE8E6F0),
                                        )
                                      : const ColorScheme.light(
                                          primary: AppTheme.primaryPink,
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Color(0xFF111827),
                                        ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => localDob = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date of birth',
                            labelStyle: TextStyle(color: AppTheme.textFaint(context), fontSize: 13),
                            filled: true,
                            fillColor: AppTheme.inputBg(context),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppTheme.border(context)),
                            ),
                          ),
                          child: Text(
                            localDob != null
                                ? "${localDob!.day}/${localDob!.month}/${localDob!.year}"
                                : "Select date of birth",
                            style: TextStyle(fontSize: 14, color: localDob != null ? AppTheme.textPrimary(context) : AppTheme.textFaint(context)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildDropdownField<String>(
                        context: context,
                        value: _countries.contains(localCountry) ? localCountry : 'Other',
                        label: 'Country',
                        items: _countries,
                        onChanged: (v) => setState(() {
                          localCountry = v;
                          localState = null;
                          localCity = null;
                        }),
                      ),
                      const SizedBox(height: 14),

                      if (isIndia) ...[
                        _buildDropdownField<String>(
                          context: context,
                          value: states.contains(localState) ? localState : null,
                          label: 'State',
                          items: states,
                          onChanged: (v) => setState(() {
                            localState = v;
                            localCity = null;
                          }),
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (isIndia)
                        _buildDropdownField<String>(
                          context: context,
                          value: cities.contains(localCity) ? localCity : null,
                          label: 'City',
                          items: cities,
                          onChanged: (v) => setState(() => localCity = v),
                        )
                      else
                        _sheetField(cityCtrl, 'City', context),
                      const SizedBox(height: 14),

                      _sheetField(phoneCtrl, 'Phone number', context, keyboardType: TextInputType.phone),
                      const SizedBox(height: 14),

                      _buildDropdownField<String>(
                        context: context,
                        value: _relStatusList.contains(localStatus) ? localStatus : null,
                        label: 'Relationship status',
                        items: _relStatusList,
                        onChanged: (v) => setState(() => localStatus = v),
                      ),
                      const SizedBox(height: 14),

                      _buildDropdownField<String>(
                        context: context,
                        value: _educationList.contains(localEducation) ? localEducation : null,
                        label: 'Education',
                        items: _educationList,
                        onChanged: (v) => setState(() => localEducation = v),
                      ),
                      const SizedBox(height: 14),

                      _sheetField(collegeCtrl, 'College / University', context),
                      const SizedBox(height: 14),

                      _sheetField(occupationCtrl, 'Occupation', context),
                      const SizedBox(height: 14),

                      _sheetField(workplaceCtrl, 'Workplace / Company', context),
                      const SizedBox(height: 14),

                      _sheetField(heightCtrl, 'Height (cm)', context, keyboardType: TextInputType.number),
                      const SizedBox(height: 14),

                      InkWell(
                        onTap: () async {
                          final selected = await _showLanguagesEditSheet(context, localLanguages);
                          if (selected != null) {
                            setState(() => localLanguages = selected);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Languages spoken',
                            labelStyle: TextStyle(color: AppTheme.textFaint(context), fontSize: 13),
                            filled: true,
                            fillColor: AppTheme.inputBg(context),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppTheme.border(context)),
                            ),
                          ),
                          child: Text(
                            localLanguages.isEmpty
                                ? "Select languages spoken"
                                : localLanguages.join(', '),
                            style: TextStyle(fontSize: 14, color: localLanguages.isEmpty ? AppTheme.textFaint(context) : AppTheme.textPrimary(context)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildDropdownField<String>(
                        context: context,
                        value: _religionList.contains(localReligion) ? localReligion : null,
                        label: 'Religion',
                        items: _religionList,
                        onChanged: (v) => setState(() => localReligion = v),
                      ),
                      const SizedBox(height: 14),

                      _buildDropdownField<String>(
                        context: context,
                        value: _goalApiValues.values.contains(localGoal)
                            ? localGoal
                            : _goalApiValues[localGoal] ?? localGoal,
                        label: 'Relationship Goal',
                        items: _goalApiValues.values.toList(),
                        itemLabel: (v) {
                          return _goalApiValues.entries
                              .firstWhere((e) => e.value == v, orElse: () => MapEntry(v, v))
                              .key;
                        },
                        onChanged: (v) => setState(() => localGoal = v),
                      ),
                      const SizedBox(height: 24),

                      _SaveBtn(() async {
                        try {
                          final hCm = int.tryParse(heightCtrl.text.trim());
                          
                          String? statusApiVal;
                          if (localStatus == 'Single') {
                            statusApiVal = 'single';
                          } else if (localStatus == 'Separated') {
                            statusApiVal = 'separated';
                          } else if (localStatus == 'Divorced') {
                            statusApiVal = 'divorced';
                          } else if (localStatus == 'Widowed') {
                            statusApiVal = 'widowed';
                          }

                          String? eduApiVal;
                          if (localEducation == 'High School') {
                            eduApiVal = 'high_school';
                          } else if (localEducation == 'Diploma') {
                            eduApiVal = 'diploma';
                          } else if (localEducation == "Bachelor's") {
                            eduApiVal = 'bachelors';
                          } else if (localEducation == "Master's") {
                            eduApiVal = 'masters';
                          } else if (localEducation == 'PhD') {
                            eduApiVal = 'phd';
                          } else if (localEducation == 'Other') {
                            eduApiVal = 'other';
                          } else {
                            eduApiVal = localEducation;
                          }

                          final payload = <String, dynamic>{
                            'name': nameCtrl.text.trim(),
                            'gender': localGender,
                            'country': localCountry,
                            'city': isIndia ? localCity?.trim() : cityCtrl.text.trim(),
                            'phone_number': phoneCtrl.text.trim(),
                            'relationship_status': statusApiVal,
                            'education_level': eduApiVal,
                            'college_university': collegeCtrl.text.trim().isEmpty ? null : collegeCtrl.text.trim(),
                            'occupation': occupationCtrl.text.trim(),
                            'workplace': workplaceCtrl.text.trim().isEmpty ? null : workplaceCtrl.text.trim(),
                            'height_cm': hCm,
                            'languages': localLanguages,
                            'religion': localReligion,
                            'relationship_goal': localGoal,
                          };

                          if (localDob != null) {
                            payload['date_of_birth'] = localDob!.toIso8601String().split('T').first;
                          }

                          await ApiService.updateProfile(payload);
                          await context.read<AuthProvider>().refreshProfile();
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (_) {}
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMatrimonyEdit(BuildContext context, ProfileModel profile) {
    String? localCaste = profile.caste;
    String? localSubCaste = profile.subCaste;
    String? localSubReligion = profile.subReligion;
    String? localIncome = profile.annualIncome;
    final casteOtherCtrl = TextEditingController(text: (profile.caste != null && !_stateCastes.values.any((list) => list.contains(profile.caste))) ? profile.caste : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (stContext, setState) {
          final derivedState = _deriveStateFromCity(profile.city);
          final stateCommunities = derivedState != null ? (_stateCastes[derivedState] ?? ['Other']) : ['Other'];
          final casteItems = ['No Caste', 'Any Caste', ...stateCommunities];

          final subCastesForCaste = (localCaste != null && !_specialCasteOptions.contains(localCaste) && localCaste != 'Other')
              ? (_subCastesByCaste[localCaste] ?? <String>[])
              : <String>[];
          final subReligionsForReligion = profile.religion != null
              ? (_subReligionByReligion[profile.religion] ?? <String>[])
              : <String>[];

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24, right: 24, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                Text('Serious Matrimony details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                const SizedBox(height: 20),
                
                if (derivedState == null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.activeBg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border(context)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: AppTheme.textFaint(context), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Select/save state in Basic Details to view caste options',
                            style: TextStyle(color: AppTheme.textFaint(context), fontSize: 13)),
                      ),
                    ]),
                  )
                else ...[
                  _buildDropdownField<String>(
                    context: context,
                    value: casteItems.contains(localCaste) ? localCaste : null,
                    label: 'Caste',
                    items: casteItems,
                    onChanged: (v) => setState(() {
                      localCaste = v;
                      localSubCaste = null;
                    }),
                  ),
                  if (localCaste == 'Other') ...[
                    const SizedBox(height: 14),
                    _sheetField(casteOtherCtrl, 'Specify Caste', context),
                  ],
                ],
                const SizedBox(height: 14),

                if (localCaste != null && !_specialCasteOptions.contains(localCaste) && localCaste != 'Other' && subCastesForCaste.isNotEmpty) ...[
                  _buildDropdownField<String>(
                    context: context,
                    value: subCastesForCaste.contains(localSubCaste) ? localSubCaste : null,
                    label: 'Sub-caste',
                    items: subCastesForCaste,
                    onChanged: (v) => setState(() => localSubCaste = v),
                  ),
                  const SizedBox(height: 14),
                ],

                if (profile.religion != null &&
                    profile.religion != 'No Religion' &&
                    profile.religion != 'Any Religion' &&
                    subReligionsForReligion.isNotEmpty) ...[
                  _buildDropdownField<String>(
                    context: context,
                    value: subReligionsForReligion.contains(localSubReligion) ? localSubReligion : null,
                    label: 'Sub-religion / Sect',
                    items: subReligionsForReligion,
                    onChanged: (v) => setState(() => localSubReligion = v),
                  ),
                  const SizedBox(height: 14),
                ],

                _buildDropdownField<String>(
                  context: context,
                  value: _incomeList.contains(localIncome)
                      ? localIncome
                      : _incomeApiValues.entries.firstWhere((e) => e.value == localIncome, orElse: () => MapEntry(localIncome ?? '', localIncome ?? '')).key,
                  label: 'Annual income',
                  items: _incomeList,
                  onChanged: (v) => setState(() => localIncome = v),
                ),
                const SizedBox(height: 20),

                _SaveBtn(() async {
                  try {
                    final incomeApiValue = localIncome != null ? (_incomeApiValues[localIncome] ?? localIncome) : null;
                    final casteValue = localCaste == 'Other'
                        ? (casteOtherCtrl.text.trim().isEmpty ? null : casteOtherCtrl.text.trim())
                        : localCaste;

                    await ApiService.updateProfile({
                      'caste': casteValue,
                      'sub_caste': localSubCaste,
                      'sub_religion': localSubReligion,
                      'annual_income': incomeApiValue,
                    });
                    await context.read<AuthProvider>().refreshProfile();
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (_) {}
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showHobbiesEdit(BuildContext context, ProfileModel profile) {
    final selectedHobbies = profile.hobbies.toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (stContext, setState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                Text('Hobbies & interests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _hobbiesList.map((h) {
                    final isSelected = selectedHobbies.contains(h);
                    return FilterChip(
                      label: Text(h),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFDF2F8),
                      checkmarkColor: AppTheme.primaryPink,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: isSelected ? AppTheme.primaryPink : AppTheme.textSecondary(context),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      backgroundColor: AppTheme.activeBg(context),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primaryPink : AppTheme.border(context),
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            selectedHobbies.add(h);
                          } else {
                            selectedHobbies.remove(h);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                _SaveBtn(() async {
                  try {
                    await ApiService.updateProfile({'hobbies': selectedHobbies.toList()});
                    await context.read<AuthProvider>().refreshProfile();
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (_) {}
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVibesEdit(BuildContext context, ProfileModel profile) {
    final selectedVibes = profile.vibes.toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (stContext, setState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                Text('Vibe adjectives',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _vibesList.map((v) {
                    final isSelected = selectedVibes.contains(v);
                    final emoji = _vibesEmojis[v] ?? '';
                    return FilterChip(
                      label: Text("$emoji $v"),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFDF2F8),
                      checkmarkColor: AppTheme.primaryPink,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: isSelected ? AppTheme.primaryPink : AppTheme.textSecondary(context),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      backgroundColor: AppTheme.activeBg(context),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primaryPink : AppTheme.border(context),
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            selectedVibes.add(v);
                          } else {
                            selectedVibes.remove(v);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                _SaveBtn(() async {
                  try {
                    await ApiService.updateProfile({'vibes': selectedVibes.toList()});
                    await context.read<AuthProvider>().refreshProfile();
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (_) {}
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLifestyleEdit(BuildContext context, ProfileModel profile) {
    String? localDrink;
    if (profile.drinking == 'never') {
      localDrink = 'Never';
    } else if (profile.drinking == 'socially') {
      localDrink = 'Occasionally';
    } else if (profile.drinking == 'often') {
      localDrink = 'Often';
    } else if (profile.drinking == 'prefer_not_to_say') {
      localDrink = 'Prefer not to say';
    } else {
      localDrink = profile.drinking;
    }

    String? localSmoke;
    if (profile.smoking == 'never') {
      localSmoke = 'Never';
    } else if (profile.smoking == 'socially') {
      localSmoke = 'Occasionally';
    } else if (profile.smoking == 'regularly') {
      localSmoke = 'Often';
    } else if (profile.smoking == 'trying_to_quit') {
      localSmoke = 'Occasionally';
    } else if (profile.smoking == 'prefer_not_to_say') {
      localSmoke = 'Prefer not to say';
    } else {
      localSmoke = profile.smoking;
    }

    String? localWorkout;
    if (profile.workout == 'never') {
      localWorkout = 'Never';
    } else if (profile.workout == 'sometimes') {
      localWorkout = 'Sometimes';
    } else if (profile.workout == 'regularly') {
      localWorkout = 'Regularly';
    } else if (profile.workout == 'daily') {
      localWorkout = 'Daily';
    } else {
      localWorkout = profile.workout;
    }

    String? localPet;
    if (profile.pets == 'dog') {
      localPet = 'Dogs';
    } else if (profile.pets == 'cat') {
      localPet = 'Cats';
    } else if (profile.pets == 'other') {
      localPet = 'Other';
    } else if (profile.pets == 'none') {
      localPet = 'None';
    } else {
      localPet = profile.pets;
    }

    String? localChildren;
    if (profile.children == 'have_and_want_more') {
      localChildren = 'Have & want more';
    } else if (profile.children == 'have_and_dont_want_more') {
      localChildren = 'Have, no more';
    } else if (profile.children == 'want') {
      localChildren = "Don't have, want";
    } else if (profile.children == 'dont_want') {
      localChildren = "Don't want";
    } else if (profile.children == 'unsure') {
      localChildren = 'Not sure';
    } else {
      localChildren = profile.children;
    }

    String? localDiet;
    if (profile.diet == 'vegetarian') {
      localDiet = 'Vegetarian';
    } else if (profile.diet == 'non_vegetarian') {
      localDiet = 'Non-Vegetarian';
    } else if (profile.diet == 'vegan') {
      localDiet = 'Vegan';
    } else if (profile.diet == 'eggetarian') {
      localDiet = 'Eggetarian';
    } else if (profile.diet == 'jain') {
      localDiet = 'Jain';
    } else if (profile.diet == 'other') {
      localDiet = 'Other';
    } else {
      localDiet = profile.diet;
    }

    final dateIdeaCtrl = TextEditingController(text: profile.firstDateIdea ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (stContext, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24, right: 24, top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 16),
                  Text('Lifestyle alignment',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                  const SizedBox(height: 20),

                  _buildDropdownField<String>(
                    context: context,
                    value: _lifestyleOptions.contains(localDrink) ? localDrink : null,
                    label: '🍹 Drinking',
                    items: _lifestyleOptions,
                    onChanged: (v) => setState(() => localDrink = v),
                  ),
                  const SizedBox(height: 14),

                  _buildDropdownField<String>(
                    context: context,
                    value: _lifestyleOptions.contains(localSmoke) ? localSmoke : null,
                    label: '🚬 Smoking',
                    items: _lifestyleOptions,
                    onChanged: (v) => setState(() => localSmoke = v),
                  ),
                  const SizedBox(height: 14),

                  _buildDropdownField<String>(
                    context: context,
                    value: _workoutOptions.contains(localWorkout) ? localWorkout : null,
                    label: '🏃 Workout',
                    items: _workoutOptions,
                    onChanged: (v) => setState(() => localWorkout = v),
                  ),
                  const SizedBox(height: 14),

                  _buildDropdownField<String>(
                    context: context,
                    value: _petsOptions.contains(localPet) ? localPet : null,
                    label: '🐾 Pets',
                    items: _petsOptions,
                    onChanged: (v) => setState(() => localPet = v),
                  ),
                  const SizedBox(height: 14),

                  _buildDropdownField<String>(
                    context: context,
                    value: _childrenOptions.contains(localChildren) ? localChildren : null,
                    label: '👶 Children',
                    items: _childrenOptions,
                    onChanged: (v) => setState(() => localChildren = v),
                  ),
                  const SizedBox(height: 14),

                  _buildDropdownField<String>(
                    context: context,
                    value: _dietOptions.contains(localDiet) ? localDiet : null,
                    label: '🥗 Diet',
                    items: _dietOptions,
                    onChanged: (v) => setState(() => localDiet = v),
                  ),
                  const SizedBox(height: 14),

                  _sheetField(dateIdeaCtrl, 'First date idea', context),
                  const SizedBox(height: 20),

                  _SaveBtn(() async {
                    try {
                      String? drinkApiVal;
                      if (localDrink == 'Never') {
                        drinkApiVal = 'never';
                      } else if (localDrink == 'Occasionally') {
                        drinkApiVal = 'socially';
                      } else if (localDrink == 'Often') {
                        drinkApiVal = 'often';
                      } else if (localDrink == 'Always') {
                        drinkApiVal = 'often';
                      } else if (localDrink == 'Prefer not to say') {
                        drinkApiVal = 'prefer_not_to_say';
                      }

                      String? smokeApiVal;
                      if (localSmoke == 'Never') {
                        smokeApiVal = 'never';
                      } else if (localSmoke == 'Occasionally') {
                        smokeApiVal = 'socially';
                      } else if (localSmoke == 'Often') {
                        smokeApiVal = 'regularly';
                      } else if (localSmoke == 'Always') {
                        smokeApiVal = 'regularly';
                      } else if (localSmoke == 'Prefer not to say') {
                        smokeApiVal = 'prefer_not_to_say';
                      }

                      String? workoutApiVal;
                      if (localWorkout == 'Never') {
                        workoutApiVal = 'never';
                      } else if (localWorkout == 'Sometimes') {
                        workoutApiVal = 'sometimes';
                      } else if (localWorkout == 'Regularly') {
                        workoutApiVal = 'regularly';
                      } else if (localWorkout == 'Daily') {
                        workoutApiVal = 'daily';
                      }

                      String? petApiVal;
                      if (localPet == 'Dogs') {
                        petApiVal = 'dog';
                      } else if (localPet == 'Cats') {
                        petApiVal = 'cat';
                      } else if (localPet == 'Birds') {
                        petApiVal = 'other';
                      } else if (localPet == 'Reptiles') {
                        petApiVal = 'other';
                      } else if (localPet == 'None') {
                        petApiVal = 'none';
                      } else if (localPet == 'Other') {
                        petApiVal = 'other';
                      }

                      String? childrenApiVal;
                      if (localChildren == 'Have & want more') {
                        childrenApiVal = 'have_and_want_more';
                      } else if (localChildren == 'Have, no more') {
                        childrenApiVal = 'have_and_dont_want_more';
                      } else if (localChildren == "Don't have, want") {
                        childrenApiVal = 'want';
                      } else if (localChildren == "Don't want") {
                        childrenApiVal = 'dont_want';
                      } else if (localChildren == 'Not sure') {
                        childrenApiVal = 'unsure';
                      }

                      String? dietApiVal;
                      if (localDiet == 'Vegetarian') {
                        dietApiVal = 'vegetarian';
                      } else if (localDiet == 'Non-Vegetarian') {
                        dietApiVal = 'non_vegetarian';
                      } else if (localDiet == 'Vegan') {
                        dietApiVal = 'vegan';
                      } else if (localDiet == 'Eggetarian') {
                        dietApiVal = 'eggetarian';
                      } else if (localDiet == 'Jain') {
                        dietApiVal = 'jain';
                      } else if (localDiet == 'Other') {
                        dietApiVal = 'other';
                      }

                      await ApiService.updateProfile({
                        'drinking': drinkApiVal,
                        'smoking': smokeApiVal,
                        'workout': workoutApiVal,
                        'pets': petApiVal,
                        'children': childrenApiVal,
                        'diet': dietApiVal,
                        'first_date_idea': dateIdeaCtrl.text.trim().isEmpty ? null : dateIdeaCtrl.text.trim(),
                      });
                      await context.read<AuthProvider>().refreshProfile();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (_) {}
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBioEdit(BuildContext context, ProfileModel profile) {
    final ctrl = TextEditingController(text: profile.bio ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24, right: 24, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft,
                child: Text('Vibe quote',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context)))),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 4,
              maxLength: 300,
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimary(context)),
              decoration: InputDecoration(
                hintText: 'What\'s your vibe? Describe yourself…',
                hintStyle: TextStyle(color: AppTheme.textFaint(context), fontSize: 14),
                filled: true, fillColor: AppTheme.inputBg(context),
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.border(context))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryPink, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            _SaveBtn(() async {
              try {
                await ApiService.updateProfile({'bio': ctrl.text.trim()});
                await context.read<AuthProvider>().refreshProfile();
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {}
            }),
          ],
        ),
      ),
    );
  }

  Widget _sheetHandle() => Center(
    child: Container(width: 36, height: 4,
        decoration: BoxDecoration(color: AppTheme.border(context),
            borderRadius: BorderRadius.circular(2))),
  );

  Widget _sheetField(TextEditingController ctrl, String label, BuildContext context, {TextInputType? keyboardType}) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary(context)),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.textFaint(context), fontSize: 13),
      filled: true, fillColor: AppTheme.inputBg(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.border(context))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryPink, width: 2)),
    ),
  );

  Future<List<String>?> _showLanguagesEditSheet(BuildContext context, List<String> current) {
    final localSelected = Set<String>.from(current);
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
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
              Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.border(context), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Select languages spoken', style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _languagesList.length,
                  itemBuilder: (context, index) {
                    final lang = _languagesList[index];
                    final isSelected = localSelected.contains(lang);
                    return CheckboxListTile(
                      title: Text(lang, style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 15)),
                      value: isSelected,
                      activeColor: AppTheme.primaryPink,
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
                    onPressed: () => Navigator.pop(ctx, localSelected.toList()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
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
}

// ── Photo grid ────────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final ProfileModel profile;
  final Future<void> Function(int slot) onPickPhoto;
  final Future<void> Function(BuildContext, String, String, bool) onShowOptions;
  final String? busyId;
  final Set<int> busySlots;

  const _PhotoGrid({
    required this.profile,
    required this.onPickPhoto,
    required this.onShowOptions,
    required this.busyId,
    required this.busySlots,
  });

  @override
  Widget build(BuildContext context) {
    final photos = profile.photoUrls;
    final ids = profile.photoIds;
    final isDark = AppTheme.isDark(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: 6,
      itemBuilder: (_, i) {
        final hasPhoto = i < photos.length;
        final hasId = i < ids.length;
        final isMain = i == 0;
        final imageId = hasId ? ids[i] : null;
        final isBusy = (imageId != null && busyId == imageId) || busySlots.contains(i);
        final isPending = isMain &&
            (profile.verificationStatus == 'pending' ||
                (profile.verificationStatus == 'none' &&
                    profile.mainPhotoUrl != null &&
                    !profile.isVerified));

        if (hasPhoto) {
          return GestureDetector(
            onTap: isBusy ? null : () {
              if (imageId != null) {
                onShowOptions(context, photos[i], imageId, isMain);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.activeBg(context),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: photos[i], fit: BoxFit.cover),
                  // Loading overlay for this specific photo
                  if (isBusy)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                      ),
                    ),
                  if (!isBusy && isMain)
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC4899),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Main',
                            style: TextStyle(color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (!isBusy && isPending)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        color: const Color(0xFFF59E0B),
                        child: const Text('Under validation',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  // Edit hint icon (bottom-right)
                  if (!isBusy && imageId != null)
                    Positioned(
                      bottom: isPending ? 28 : 6, right: 6,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        // Empty slot
        return GestureDetector(
          onTap: isBusy ? null : () => onPickPhoto(i),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.activeBg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBusy ? const Color(0xFFEC4899).withOpacity(0.4) : const Color(0xFFEC4899),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: isBusy
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFEC4899), strokeWidth: 2.5),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D1B28) : const Color(0xFFFDF2F8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined,
                            size: 20, color: Color(0xFFEC4899)),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ── Photo options dialog (tap existing photo) ─────────────────────────────────

class _PhotoOptionsDialog extends StatelessWidget {
  final String imageUrl;
  final bool isMain;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSetMain;

  const _PhotoOptionsDialog({
    required this.imageUrl,
    required this.isMain,
    required this.onEdit,
    required this.onDelete,
    this.onSetMain,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview with action buttons overlaid
          Stack(
            children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                ),
              ),
              // Close
              Positioned(
                top: 12, left: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
              // Action buttons — right side
              Positioned(
                top: 12, right: 12,
                child: Column(
                  children: [
                    // Edit
                    _ActionChip(
                      icon: Icons.crop_rotate_rounded,
                      label: 'Edit',
                      color: const Color(0xFF3B82F6),
                      onTap: onEdit,
                    ),
                    const SizedBox(height: 10),
                    // Set as main (if not already)
                    if (onSetMain != null)
                      _ActionChip(
                        icon: Icons.star_rounded,
                        label: 'Main',
                        color: const Color(0xFFEC4899),
                        onTap: onSetMain!,
                      ),
                    if (onSetMain != null) const SizedBox(height: 10),
                    // Delete
                    _ActionChip(
                      icon: Icons.delete_rounded,
                      label: 'Delete',
                      color: const Color(0xFFEF4444),
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
              // Main badge
              if (isMain)
                Positioned(
                  bottom: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Main photo',
                      style: TextStyle(color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}

// ── Basic details ─────────────────────────────────────────────────────────────

class _BasicDetails extends StatelessWidget {
  final ProfileModel profile;
  const _BasicDetails({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    if (profile.name?.isNotEmpty == true) rows.add(('Display name', profile.name!));
    if (profile.gender?.isNotEmpty == true) {
      final genderLabel = profile.gender == 'male'
          ? 'Male'
          : profile.gender == 'female'
              ? 'Female'
              : profile.gender == 'non_binary'
                  ? 'Non-binary'
                  : 'Prefer not to say';
      rows.add(('Gender', genderLabel));
    }
    if (profile.dateOfBirth?.isNotEmpty == true) rows.add(('Date of birth', profile.dateOfBirth!));
    if (profile.country?.isNotEmpty == true) rows.add(('Country', profile.country!));
    final derivedState = _deriveStateFromCity(profile.city);
    if (derivedState != null) rows.add(('State', derivedState));
    if (profile.city?.isNotEmpty == true) rows.add(('City', profile.city!));
    if (profile.phoneNumber?.isNotEmpty == true) rows.add(('Phone number', profile.phoneNumber!));
    if (profile.relationshipStatus?.isNotEmpty == true) rows.add(('Relationship status', profile.relationshipStatus!));
    if (profile.education?.isNotEmpty == true) rows.add(('Education', profile.education!));
    if (profile.collegeUniversity?.isNotEmpty == true) rows.add(('College / University', profile.collegeUniversity!));
    if (profile.occupation?.isNotEmpty == true) rows.add(('Occupation', profile.occupation!));
    if (profile.workplace?.isNotEmpty == true) rows.add(('Workplace', profile.workplace!));
    if (profile.heightCm != null) rows.add(('Height', '${profile.heightCm} cm'));
    if (profile.languages.isNotEmpty) rows.add(('Languages spoken', profile.languages.join(', ')));
    if (profile.religion?.isNotEmpty == true) rows.add(('Religion', profile.religion!));
    if (profile.relationshipGoal?.isNotEmpty == true)
      rows.add(('Relationship Goal', formatRelationshipGoal(profile.relationshipGoal!)));

    if (rows.isEmpty) return Text('No details added yet',
        style: TextStyle(color: AppTheme.textFaint(context), fontSize: 13));

    return Column(
      children: rows.asMap().entries.map((e) {
        final isLast = e.key == rows.length - 1;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 130,
                      child: Text(e.value.$1,
                          style: TextStyle(fontSize: 13, color: AppTheme.textFaint(context)))),
                  Expanded(child: Text(e.value.$2,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(context)))),
                ],
              ),
            ),
            if (!isLast) Divider(height: 1, color: AppTheme.border(context)),
          ],
        );
      }).toList(),
    );
  }
}

// ── Serious Matrimony details ─────────────────────────────────────────────────

class _MatrimonyDetails extends StatelessWidget {
  final ProfileModel profile;
  const _MatrimonyDetails({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    if (profile.caste?.isNotEmpty == true) rows.add(('Caste', profile.caste!));
    if (profile.subCaste?.isNotEmpty == true) rows.add(('Sub-caste', profile.subCaste!));
    if (profile.subReligion?.isNotEmpty == true) rows.add(('Sub-religion / Sect', profile.subReligion!));
    if (profile.annualIncome?.isNotEmpty == true) {
      final label = _incomeList.contains(profile.annualIncome)
          ? profile.annualIncome!
          : _incomeApiValues.entries.firstWhere(
              (e) => e.value == profile.annualIncome,
              orElse: () => MapEntry(profile.annualIncome ?? '', profile.annualIncome ?? ''),
            ).key;
      if (label.isNotEmpty) {
        rows.add(('Annual income', label));
      }
    }

    if (rows.isEmpty) return Text('No matrimony details added yet',
        style: TextStyle(color: AppTheme.textFaint(context), fontSize: 13));

    return Column(
      children: rows.asMap().entries.map((e) {
        final isLast = e.key == rows.length - 1;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 130,
                      child: Text(e.value.$1,
                          style: TextStyle(fontSize: 13, color: AppTheme.textFaint(context)))),
                  Expanded(child: Text(e.value.$2,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(context)))),
                ],
              ),
            ),
            if (!isLast) Divider(height: 1, color: AppTheme.border(context)),
          ],
        );
      }).toList(),
    );
  }
}

// ── Lifestyle chips ───────────────────────────────────────────────────────────

class _LifestyleChips extends StatelessWidget {
  final ProfileModel profile;
  const _LifestyleChips({required this.profile});

  List<String> _labels() {
    final labels = <String>[];
    final p = profile;
    if (p.pets != null) labels.add('🐾 ${_petLabel(p.pets!)}');
    if (p.workout != null) labels.add('🏃 ${p.workout!}');
    if (p.drinking != null) labels.add('🍹 ${p.drinking!}');
    if (p.smoking != null) labels.add('🚬 ${p.smoking!}');
    if (p.children != null) labels.add('👶 ${p.children!}');
    if (p.diet != null) labels.add('🥗 ${p.diet!}');
    return labels;
  }

  String _petLabel(String v) {
    if (v.contains('love')) return 'I love pets and open to having one';
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels();
    if (labels.isEmpty) return _AddButton('Add lifestyle info', () {});
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.map((l) => _Chip(l)).toList(),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _CoverPhotoRow extends StatelessWidget {
  final String? coverUrl;
  final bool saving;
  final VoidCallback onPick;
  final VoidCallback onDelete;
  const _CoverPhotoRow({
    required this.coverUrl, required this.saving,
    required this.onPick, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (coverUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: coverUrl!,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: saving ? null : onPick,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.activeBg(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border(context)),
                    ),
                    child: Center(
                      child: Text('Change cover', style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600, color: AppTheme.textSecondary(context))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: saving ? null : onDelete,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3D1B1B) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF5D2B2B) : const Color(0xFFFECACA)),
                  ),
                  child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
        ] else ...[
          GestureDetector(
            onTap: saving ? null : onPick,
            child: Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.activeBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context), style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 28, color: AppTheme.textFaint(context)),
                  const SizedBox(height: 6),
                  Text('Add cover photo', style: TextStyle(fontSize: 13,
                      color: AppTheme.textFaint(context), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'Shown as a wide banner at the top of your profile.',
          style: TextStyle(fontSize: 11, color: AppTheme.textFaint(context)),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String? editLabel;
  final VoidCallback? onEdit;
  const _SectionCard({required this.title, required this.child, this.editLabel, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context))),
              const Spacer(),
              if (editLabel != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 13, color: Color(0xFFEC4899)),
                      const SizedBox(width: 3),
                      Text(editLabel!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFEC4899),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.activeBg(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Text(text, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
  );
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddButton(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEC4899), style: BorderStyle.solid),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add, size: 16, color: Color(0xFFEC4899)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFFEC4899),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}

class _SaveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveBtn(this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.3),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: const Center(
        child: Text('Save Changes',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    ),
  );
}

// ── Compatibility Q&A bottom sheet ──────────────────────────────────────────

class _CompatibilitySheet extends StatefulWidget {
  final List<CompatibilityQuestion> questions;
  final Map<String, String> initial;
  final Future<void> Function(List<Map<String, dynamic>>) onSave;

  const _CompatibilitySheet({
    required this.questions,
    required this.initial,
    required this.onSave,
  });

  @override
  State<_CompatibilitySheet> createState() => _CompatibilitySheetState();
}

class _CompatibilitySheetState extends State<_CompatibilitySheet> {
  late final Map<String, String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = Map.from(widget.initial);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final answers = widget.questions
        .where((q) => _selected.containsKey(q.question))
        .map((q) => {'question': q.question, 'answer': _selected[q.question]!})
        .toList();
    await widget.onSave(answers);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          // Handle + header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text('Compatibility questions',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context))),
                    ),
                    Text('${_selected.length}/${widget.questions.length}',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textFaint(context))),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Answer to show on your profile',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.border(context)),

          // Questions list
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: widget.questions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 20),
              itemBuilder: (_, i) {
                final q = widget.questions[i];
                return _QuestionTile(
                  question: q,
                  selected: _selected[q.question],
                  onSelect: (ans) => setState(() {
                    if (_selected[q.question] == ans) {
                      _selected.remove(q.question);
                    } else {
                      _selected[q.question] = ans;
                    }
                  }),
                );
              },
            ),
          ),

          // Save button
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              boxShadow: [
                BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.07),
                    blurRadius: 10,
                    offset: const Offset(0, -3))
              ],
            ),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Save answers',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final CompatibilityQuestion question;
  final String? selected;
  final void Function(String) onSelect;

  const _QuestionTile({
    required this.question,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.question,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(context))),
        const SizedBox(height: 10),
        ...question.options.map((opt) {
          final isSelected = opt == selected;
          return GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF2E1B29) : const Color(0xFFFDF2F8))
                    : AppTheme.activeBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFEC4899)
                      : AppTheme.border(context),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(opt,
                        style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? const Color(0xFFEC4899)
                                : AppTheme.textSecondary(context),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        size: 18, color: Color(0xFFEC4899))
                  else
                    Icon(Icons.radio_button_unchecked,
                        size: 18, color: AppTheme.textFaint(context)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
