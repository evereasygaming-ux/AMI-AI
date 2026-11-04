import 'package:flutter/material.dart';

import '../ami_controller.dart';
import '../app_theme.dart';
import '../models/local_note.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key, required this.controller});

  final AmiController controller;

  @override
  Widget build(BuildContext context) {
    final notes = controller.notes;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        const Text(
          'Notes',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        const Text(
          'Saved on this phone by AMI.',
          style: TextStyle(fontSize: 12.5, color: AmiColors.muted),
        ),
        const SizedBox(height: 18),
        if (notes.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: glassPanel(radius: 20),
            child: const Text(
              'No notes yet. Ask AMI to save something for you.',
              style: TextStyle(color: AmiColors.muted, height: 1.45),
            ),
          )
        else
          for (final note in notes) ...[
            _NoteCard(
              note: note,
              onDelete: () => controller.deleteNote(note.id),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onDelete});

  final LocalNote note;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
    decoration: glassPanel(radius: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.content,
                  style: const TextStyle(color: AmiColors.muted, height: 1.4),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                MaterialLocalizations.of(context)
                    .formatMediumDate(note.createdAt),
                style: const TextStyle(fontSize: 10, color: AmiColors.muted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onDelete,
          tooltip: 'Delete note',
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
        ),
      ],
    ),
  );
}
