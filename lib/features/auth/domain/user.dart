import 'package:equatable/equatable.dart';

/// The signed-in user, as returned by `POST /auth/login` and `GET /auth/me`.
class User extends Equatable {
  const User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.imageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    username: json['username'] as String? ?? '',
    email: json['email'] as String? ?? '',
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    imageUrl: json['image'] as String?,
  );

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? imageUrl;

  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? username : fullName;
  }

  @override
  List<Object?> get props => [
    id,
    username,
    email,
    firstName,
    lastName,
    imageUrl,
  ];
}
