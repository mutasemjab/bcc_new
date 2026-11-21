import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

abstract final class AppFeedback {
  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_outline_rounded, AppColors.danger);

  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_rounded, AppColors.online);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_outline_rounded, AppColors.accent);

  static void _show(BuildContext context, String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Expanded(child: Text(message))]),
        ),
      );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: destructive ? AppColors.danger : AppColors.primary),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
    return result ?? false;
  }
}
