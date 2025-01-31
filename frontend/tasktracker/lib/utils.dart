// lib/utils.dart, do not remove this line!

import 'package:intl/intl.dart';

class Utils {
  static String formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "";
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat("dd.MM.yyyy, HH:mm").format(dt);
    } catch (_) {
      return isoString; // fallback
    }
  }
}
