class DiscoverProfile {
  final String userId;
  final String name;
  final int? age;
  final String? city;
  final String? bio;
  final String? mainPhotoUrl;
  final List<String> photoUrls;
  final String? education;
  final String? religion;
  final String? relationshipGoal;
  final List<String> hobbies;
  final List<String> vibes;
  final bool isVerified;
  final bool likedMe;
  final List<Map<String, dynamic>> compatibilityAnswers;

  DiscoverProfile({
    required this.userId,
    required this.name,
    this.age,
    this.city,
    this.bio,
    this.mainPhotoUrl,
    this.photoUrls = const [],
    this.education,
    this.religion,
    this.relationshipGoal,
    this.hobbies = const [],
    this.vibes = const [],
    this.isVerified = false,
    this.likedMe = false,
    this.compatibilityAnswers = const [],
  });

  factory DiscoverProfile.fromJson(Map<String, dynamic> json) {
    // Images come as list of {image_url: ...} under 'images'
    final imagesList = json['images'] as List? ?? [];
    final photoUrls = imagesList
        .map((img) => img['image_url'] as String?)
        .whereType<String>()
        .toList();

    return DiscoverProfile(
      // DB uses 'id' as primary key
      userId: json['id'] as String? ?? json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      age: json['age'] as int?,
      city: json['city'] as String?,
      bio: json['bio'] as String?,
      // DB uses main_image_url
      mainPhotoUrl: json['main_image_url'] as String?,
      photoUrls: photoUrls,
      education: json['education_level'] as String? ?? json['education'] as String?,
      religion: json['religion'] as String?,
      relationshipGoal: json['relationship_goal'] as String?,
      hobbies: List<String>.from(json['hobbies'] ?? []),
      vibes: List<String>.from(json['vibes'] ?? []),
      isVerified: json['is_verified'] as bool? ?? false,
      likedMe: json['liked_me'] as bool? ?? json['has_liked_me'] as bool? ?? false,
      compatibilityAnswers: (json['compatibility_answers'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  String? get displayPhoto => mainPhotoUrl ?? (photoUrls.isNotEmpty ? photoUrls.first : null);
}
