class Notifikasi {
  final int? idNotifikasi;
  final int idUser;
  final String judul;
  final String pesan;
  final bool isRead;
  final DateTime timestamp;

  Notifikasi({
    this.idNotifikasi,
    required this.idUser,
    required this.judul,
    required this.pesan,
    this.isRead = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id_notifikasi': idNotifikasi,
        'id_user': idUser,
        'judul': judul,
        'pesan': pesan,
        'is_read': isRead ? 1 : 0,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Notifikasi.fromJson(Map<String, dynamic> json) => Notifikasi(
        idNotifikasi: json['id_notifikasi'] as int?,
        idUser: json['id_user'] as int,
        judul: (json['judul'] as String?) ?? '',
        pesan: (json['pesan'] as String?) ?? '',
        isRead: json['is_read'] is int
            ? (json['is_read'] as int) == 1
            : (json['is_read'] as bool? ?? false),
        timestamp: json['timestamp'] is DateTime
            ? json['timestamp'] as DateTime
            : DateTime.parse(json['timestamp'] as String),
      );
}
