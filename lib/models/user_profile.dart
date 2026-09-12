import 'package:flutter/foundation.dart';

/// The person using the app. Shown on the Home greeting and Profile header.
@immutable
class UserProfile {
  const UserProfile({
    required this.name,
    this.personalQuote = 'Progress, not perfection.',
    this.photoPath,
  });

  final String name;

  /// A photograph of the person, copied into the app's own directory.
  ///
  /// A path rather than the bytes: the profile goes into the same preferences
  /// blob as everything else, and a base64 photograph in there would be read
  /// and re-encoded on every save of every unrelated field. Null means the
  /// leaf mark, which is the default and a perfectly good answer.
  final String? photoPath;

  /// Editable quote shown in the Profile quote bar.
  final String personalQuote;

  /// First name only, for the Home greeting.
  String get firstName => name.split(' ').first;

  /// Initial shown in the small circular avatar in headers.
  String get initial => name.isEmpty ? '?' : name.trim()[0].toUpperCase();

  /// [clearPhoto] because passing null to [photoPath] cannot mean "remove it"
  /// while it also means "leave it alone".
  UserProfile copyWith({
    String? name,
    String? personalQuote,
    String? photoPath,
    bool clearPhoto = false,
  }) => UserProfile(
    name: name ?? this.name,
    personalQuote: personalQuote ?? this.personalQuote,
    photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'personalQuote': personalQuote,
    'photoPath': photoPath,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? 'Friend',
    personalQuote:
        json['personalQuote'] as String? ?? 'Progress, not perfection.',
    photoPath: json['photoPath'] as String?,
  );

  /// Nobody yet.
  ///
  /// It used to be a hard-coded name, which meant a fresh install greeted
  /// every user as one particular person and deleting the account handed that
  /// name straight back. The sign-in screen is what fills this in.
  static const UserProfile empty = UserProfile(name: '');
}
