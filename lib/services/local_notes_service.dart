import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_note.dart';

class LocalNotesService {
  static const _storageKey = 'ami_local_notes';

  Future<List<LocalNote>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => LocalNote.fromJson(
              entry.map((key, value) => MapEntry('$key', value)),
            ),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<LocalNote> create({
    required String title,
    required String content,
  }) async {
    final current = await load();
    final now = DateTime.now();
    final note = LocalNote(
      id: now.microsecondsSinceEpoch.toString(),
      title: title.trim(),
      content: content.trim(),
      createdAt: now,
    );
    await _save([note, ...current]);
    return note;
  }

  Future<void> delete(String id) async {
    final current = await load();
    await _save(current.where((note) => note.id != id).toList());
  }

  Future<void> _save(List<LocalNote> notes) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(notes.map((note) => note.toJson()).toList()),
    );
  }
}
