import 'package:intl/intl.dart';

/// "just now", "5m ago", "3h ago", "2d ago", or a date for older items.
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return formatDate(d);
}

/// e.g. "Nov 25, 2026"
String formatDate(DateTime? d) => d == null ? '—' : DateFormat.yMMMd().format(d);

/// e.g. "Nov 25, 2026 3:04 PM"
String formatDateTime(DateTime d) => DateFormat.yMMMd().add_jm().format(d);

/// API date format (YYYY-MM-DD)
String apiDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Relative due date: "Due today", "Due in 3 days", "Overdue by 2 days"
String dueLabel(DateTime due) {
  final today = DateTime.now();
  final days = DateTime(due.year, due.month, due.day).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days > 1) return 'Due in $days days';
  return 'Overdue by ${-days} day${days == -1 ? '' : 's'}';
}

String fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// Two-letter initials for avatars: "Guru Prasad" → "GP"
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
