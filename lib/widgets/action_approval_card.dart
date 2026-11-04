import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/screen_action.dart';

class ActionApprovalCard extends StatelessWidget {
  const ActionApprovalCard({
    super.key,
    required this.action,
    required this.onCancel,
    required this.onApprove,
  });

  final AssistantAction action;
  final VoidCallback onCancel;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AmiColors.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AmiColors.cyan.withValues(alpha: .45)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AMI wants your approval',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: SingleChildScrollView(
            child: Text(
              action.description,
              style: const TextStyle(fontSize: 12, color: AmiColors.muted),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onApprove,
              child: const Text('Approve this action'),
            ),
          ],
        ),
      ],
    ),
  );
}
