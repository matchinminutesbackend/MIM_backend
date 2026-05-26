class ProfileModel {
  final String userId;
  final String? name;
  final String? bio;
  final int? age;
  final String? gender;
  final String? city;
  final String? country;
  final String? education;
  final String? religion;
  final String? relationshipStatus;
  final String? relationshipGoal;
  final List<String> hobbies;
  final List<String> vibes;
  final String? drinking;
  final String? smoking;
  final String? workout;
  final String? pets;
  final String? children;
  final String? diet;
  final bool isComplete;
  final bool isVerified;
  final String? verificationStatus; // none | pending | approved | rejected
  final String? verificationNote;   // admin rejection reason
  final String? mainPhotoUrl;
  final List<String> photoUrls;
  final List<String> photoIds;
  final int walletCredits;
  final String? subscriptionPlan;
  final String? coverPhotoUrl;
  final List<Map<String, dynamic>> compatibilityAnswers;
  
  // Matrimony & additional onboarding fields
  final String? caste;
  final String? subCaste;
  final String? subReligion;
  final String? annualIncome;
  final int? heightCm;
  final List<String> languages;
  final String? firstDateIdea;
  final String? occupation;
  final String? dateOfBirth;
  final String? preferredGender;
  final String? phoneNumber;
  final String? collegeUniversity;
  final String? workplace;

  ProfileModel({
    required this.userId,
    this.name,
    this.bio,
    this.age,
    this.gender,
    this.city,
    this.country,
    this.education,
    this.religion,
    this.relationshipStatus,
    this.relationshipGoal,
    this.hobbies = const [],
    this.vibes = const [],
    this.drinking,
    this.smoking,
    this.workout,
    this.pets,
    this.children,
    this.diet,
    this.isComplete = false,
    this.isVerified = false,
    this.verificationStatus,
    this.verificationNote,
    this.mainPhotoUrl,
    this.photoUrls = const [],
    this.photoIds = const [],
    this.walletCredits = 0,
    this.subscriptionPlan,
    this.coverPhotoUrl,
    this.compatibilityAnswers = const [],
    this.caste,
    this.subCaste,
    this.subReligion,
    this.annualIncome,
    this.heightCm,
    this.languages = const [],
    this.firstDateIdea,
    this.occupation,
    this.dateOfBirth,
    this.preferredGender,
    this.phoneNumber,
    this.collegeUniversity,
    this.workplace,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // Profile images come as list of {image_url: ...} objects under 'images'
    final imagesList = json['images'] as List? ?? [];
    final photoUrls = imagesList
        .map((img) => img['image_url'] as String?)
        .whereType<String>()
        .toList();
    final photoIds = imagesList
        .map((img) => (img['id'] ?? img['image_id'])?.toString())
        .whereType<String>()
        .toList();

    return ProfileModel(
      // DB uses 'id' as primary key
      userId: json['id'] as String? ?? json['user_id'] as String? ?? '',
      name: json['name'] as String?,
      bio: json['bio'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      education: json['education_level'] as String? ?? json['education'] as String?,
      religion: json['religion'] as String?,
      relationshipStatus: json['relationship_status'] as String?,
      relationshipGoal: json['relationship_goal'] as String?,
      hobbies: List<String>.from(json['hobbies'] ?? []),
      vibes: List<String>.from(json['vibes'] ?? []),
      drinking: json['drinking'] as String?,
      smoking: json['smoking'] as String?,
      workout: json['workout'] as String?,
      pets: json['pets'] as String?,
      children: json['children'] as String?,
      diet: json['diet'] as String?,
      isComplete: json['is_complete'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      verificationStatus: json['verification_status'] as String?,
      verificationNote: json['verification_note'] as String?,
      // DB uses main_image_url
      mainPhotoUrl: json['main_image_url'] as String?,
      photoUrls: photoUrls,
      photoIds: photoIds,
      walletCredits: json['wallet_credits'] as int? ?? 0,
      subscriptionPlan: json['subscription_plan'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      compatibilityAnswers: (json['compatibility_answers'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      caste: json['caste'] as String?,
      subCaste: json['sub_caste'] as String?,
      subReligion: json['sub_religion'] as String?,
      annualIncome: json['annual_income'] as String?,
      heightCm: json['height_cm'] as int?,
      languages: List<String>.from(json['languages'] ?? []),
      firstDateIdea: json['first_date_idea'] as String?,
      occupation: json['occupation'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      preferredGender: json['preferred_gender'] as String?,
      phoneNumber: json['phone_number'] as String?,
      collegeUniversity: json['college_university'] as String?,
      workplace: json['workplace'] as String?,
    );
  }
}

