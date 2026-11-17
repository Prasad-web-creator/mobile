class User {
  final String id;
  final String name;
  final String email;
  final String? phone;

  /// A contact must be verified (by OTP) before it can be used to log in.
  final bool emailVerified;
  final bool phoneVerified;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.emailVerified = false,
    this.phoneVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      emailVerified: json['emailVerified'] == true,
      phoneVerified: json['phoneVerified'] == true,
    );
  }
}
