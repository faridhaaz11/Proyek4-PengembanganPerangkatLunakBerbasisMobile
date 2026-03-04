import 'package:intl/intl.dart';

/// Mengformat [DateTime] ke teks lokal Indonesia.
///
/// - < 1 menit  : "Baru saja"
/// - < 60 menit : "X menit yang lalu"
/// - < 24 jam   : "X jam yang lalu"
/// - Kemarin    : "Kemarin, HH:mm"
/// - Tahun ini  : "25 Jan, HH:mm"
/// - Tahun lalu : "25 Jan 2025"
class TimeFormatter {
  TimeFormatter._();

  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return 'Baru saja';
    }

    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m menit yang lalu';
    }

    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h jam yang lalu';
    }

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == yesterday) {
      final time = DateFormat('HH:mm').format(date);
      return 'Kemarin, $time';
    }

    if (date.year == now.year) {
      // Format: "25 Jan, 14:30"
      return DateFormat("d MMM, HH:mm", "id_ID").format(date);
    }

    // Format: "25 Jan 2025"
    return DateFormat("d MMM yyyy", "id_ID").format(date);
  }
}
