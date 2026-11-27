class User {
  final String id;
  final String name;
  final String email;
  final String? phone;

  /// Whether ownership of the email address has been verified.
  final bool emailVerified;
  final bool googleLinked;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.emailVerified = false,
    this.googleLinked = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      emailVerified: json['emailVerified'] == true,
      googleLinked: json['googleLinked'] == true,
    );
  }
}
