import 'package:cloud_firestore/cloud_firestore.dart';

/// Small helpers to read loosely-typed Firestore maps safely.
extension FirestoreMapX on Map<String, dynamic> {
  String str(String key, [String fallback = '']) => (this[key] as String?) ?? fallback;
  String? strOrNull(String key) => this[key] as String?;
  int integer(String key, [int fallback = 0]) => (this[key] as num?)?.toInt() ?? fallback;
  double? dbl(String key) => (this[key] as num?)?.toDouble();
  bool boolean(String key, [bool fallback = false]) => (this[key] as bool?) ?? fallback;

  DateTime? date(String key) {
    final v = this[key];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  List<String> strList(String key) => (this[key] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];

  Map<String, T> mapOf<T>(String key, T Function(dynamic) convert) {
    final raw = this[key] as Map<String, dynamic>?;
    if (raw == null) return {};
    return raw.map((k, v) => MapEntry(k, convert(v)));
  }
}
