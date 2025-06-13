import 'user.dart';

class FollowUp {

  final int id;
  final User follower;
  final User followed;

  FollowUp({
    required this.id,
    required this.follower,
    required this.followed,
  });

  factory FollowUp.fromJson(Map<String, dynamic> json) {
    if (json['idFollowUp'] == null || json['follower'] == null || json['followed'] == null) {
      throw const FormatException("El JSON de FollowUp no contiene los campos requeridos.");
    }

    return FollowUp(
      id: json['idFollowUp'] as int,
      follower: User.fromJson(json['follower']),
      followed: User.fromJson(json['followed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idFollowUp': id,
      'follower': follower.toJson(),
      'followed': followed.toJson(),
    };
  }
}
