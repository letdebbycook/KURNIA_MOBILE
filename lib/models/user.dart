class AppUser {
  final int? idUser;
  final String username;
  final String password;
  final String email;
  final String nama;
  final String telepon;

  AppUser({
    this.idUser,
    required this.username,
    required this.password,
    required this.email,
    required this.nama,
    required this.telepon,
  });

  Map<String, dynamic> toJson() => {
        'id_user': idUser,
        'username': username,
        'password': password,
        'email': email,
        'nama': nama,
        'telepon': telepon,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        idUser: json['id_user'] as int?,
        username: json['username'] as String,
        password: json['password'] as String,
        email: json['email'] as String,
        nama: json['nama'] as String,
        telepon: json['telepon'] as String,
      );
}
