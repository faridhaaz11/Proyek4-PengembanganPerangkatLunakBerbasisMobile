import 'package:mongo_dart/mongo_dart.dart';

class LogModel {
  final ObjectId? id; // Penanda unik global dari MongoDB
  final String username; // Pemilik data
  final String title;
  final DateTime date;
  final String description;
  final String category;

  LogModel({
    this.id,
    required this.username,
    required this.title,
    required this.date,
    required this.description,
    required this.category,
  });

  // [CONVERT] Memasukkan data ke "Kardus" (BSON/Map) untuk dikirim ke Cloud
  Map<String, dynamic> toMap() {
    return {
      '_id': id ?? ObjectId(), // Buat ID otomatis jika belum ada
      'username': username,
      'title': title,
      'description': description,
      'date': date.toIso8601String(), // Simpan tanggal dalam format standar
      'category': category,
    };
  }

  // [REVERT] Membongkar "Kardus" (BSON/Map) kembali menjadi objek Flutter
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: map['_id'] is ObjectId ? map['_id'] as ObjectId : null,
      username: map['username'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      category: map['category'] ?? 'Pekerjaan',
    );
  }
}
