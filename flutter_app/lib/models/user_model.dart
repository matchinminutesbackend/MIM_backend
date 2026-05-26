class UserModel {
  final String id;
  final String email;
  final String? name;

  UserModel({required this.id, required this.email, this.name});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['user_id'] ?? json['id'] ?? '',
        email: json['email'] ?? '',
        name: json['name'],
      );

  Map<String, dynamic> toJson() => {'user_id': id, 'email': email, 'name': name};
}
