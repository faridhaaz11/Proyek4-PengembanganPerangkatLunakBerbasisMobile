import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'log_model.g.dart';

@HiveType(typeId: 0)
class LogModel {
  @HiveField(0)
  final String? id; // Disimpan sebagai String hex agar kompatibel dengan Hive

  @HiveField(1)
  final String username; // Pemilik data

  @HiveField(2)
  final String title;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String description;

  @HiveField(5)
  final String category;

  @HiveField(6)
  final String authorId; // Identitas penulis (RBAC)

  @HiveField(7)
  final String teamId; // Identitas kelompok untuk Collaborative Sync

  @HiveField(8)
  final bool isPublic; // Visibilitas: false = Private (default), true = Public

  @HiveField(9)
  final DateTime? syncedAt; // Waktu saat berhasil di-sync ke MongoDB (null = belum sync)

  LogModel({
    this.id,
    required this.username,
    required this.title,
    required this.date,
    required this.description,
    required this.category,
    this.authorId = 'unknown_user',
    this.teamId = 'no_team',
    this.isPublic = false,
    this.syncedAt,
  });
  // [CONVERT] Memasukkan data ke "Kardus" (BSON/Map) untuk dikirim ke Cloud
  Map<String, dynamic> toMap() {
    return {
      '_id': id != null
          ? ObjectId.fromHexString(id!)
          : ObjectId(), // Konversi String → ObjectId untuk MongoDB
      'username': username,
      'title': title,
      'description': description,
      'date': date.toIso8601String(), // Simpan tanggal dalam format standar
      'category': category,
      'authorId': authorId,
      'teamId': teamId,
      'isPublic': isPublic,
      'syncedAt': syncedAt?.toIso8601String(), // Waktu sync (null jika belum)
    };
  }

  // [REVERT] Membongkar "Kardus" (BSON/Map) kembali menjadi objek Flutter
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: (map['_id'] as ObjectId?)?.oid, // Konversi ObjectId → String hex
      username: map['username'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      category: map['category'] ?? 'Pekerjaan',
      authorId: map['authorId'] ?? 'unknown_user', // Cegah error null
      teamId: map['teamId'] ?? 'no_team',
      isPublic:
          map['isPublic'] as bool? ?? false, // Default private jika belum ada
      syncedAt: map['syncedAt'] != null
          ? DateTime.parse(map['syncedAt'])
          : null,
    );
  }
}
