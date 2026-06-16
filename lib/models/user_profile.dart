class UserProfile {
  final String username;
  final String fullName;
  final String phoneNumber;
  final String alamat;
  final String imageUrl;

  UserProfile({
    required this.username,
    required this.fullName,
    required this.phoneNumber,
    this.alamat = '',
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'alamat': alamat,
        'imageUrl': imageUrl,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        username: json['username'] as String,
        fullName: json['fullName'] as String,
        phoneNumber: json['phoneNumber'] as String,
        alamat: (json['alamat'] as String?) ?? '',
        imageUrl: json['imageUrl'] as String,
      );
}
