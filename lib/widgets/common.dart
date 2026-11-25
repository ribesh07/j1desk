import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// Rounded GitHub-style badge ("Label") in one of the color tones.
class ToneBadge extends StatelessWidget {
  final String text;
  final Tone tone;
  final IconData? icon;
  final bool dot;

  const ToneBadge({super.key, required this.text, required this.tone, this.icon, this.dot = false});

  @override
  Widget build(BuildContext context) {
    final t = context.colors.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(width: 7, height: 7, decoration: BoxDecoration(color: t.fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
        ],
        if (icon != null) ...[Icon(icon, size: 12, color: t.fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: t.fg, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4)),
      ]),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final m = metaOf(statusMeta, status);
    return ToneBadge(text: m.label, tone: m.tone, dot: true);
  }
}

class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge(this.priority, {super.key});

  @override
  Widget build(BuildContext context) {
    final m = metaOf(priorityMeta, priority);
    return ToneBadge(text: m.label, tone: m.tone, icon: priorityIcon(priority));
  }
}

IconData priorityIcon(String p) => switch (p) {
      'CRITICAL' => Icons.keyboard_double_arrow_up,
      'HIGH' => Icons.keyboard_arrow_up,
      'LOW' => Icons.keyboard_arrow_down,
      _ => Icons.drag_handle,
    };

IconData typeIcon(String t) => switch (t) {
      'BUG' => Icons.bug_report_outlined,
      'FEATURE' => Icons.auto_awesome_outlined,
      'IMPROVEMENT' => Icons.trending_up,
      'SUPPORT' => Icons.support_agent,
      'RESEARCH' => Icons.science_outlined,
      _ => Icons.check_box_outlined,
    };

/// Small colored icon showing the ticket status (like GitHub's issue icons).
class StatusIcon extends StatelessWidget {
  final String status;
  final double size;
  const StatusIcon(this.status, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final color = context.colors.tone(metaOf(statusMeta, status).tone).fg;
    final icon = switch (status) {
      'RESOLVED' || 'CLOSED' => Icons.check_circle_outline,
      'REJECTED' => Icons.cancel_outlined,
      'IN_PROGRESS' => Icons.timelapse,
      'IN_REVIEW' => Icons.visibility_outlined,
      'ON_HOLD' || 'PENDING' => Icons.pause_circle_outline,
      'BACKLOG' => Icons.radio_button_unchecked,
      _ => Icons.adjust,
    };
    return Icon(icon, size: size, color: color);
  }
}

/// Label pill using the label's own hex color.
class LabelChip extends StatelessWidget {
  final Label label;
  const LabelChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = hexColor(label.color);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.18 : 0.9),
        border: Border.all(color: color.withValues(alpha: dark ? 0.5 : 1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.name,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: dark ? Color.lerp(color, Colors.white, 0.35) : (color.computeLuminance() > 0.5 ? Colors.black : Colors.white),
        ),
      ),
    );
  }
}

Color hexColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16) ?? 0xFF888888);
}

/// Circle avatar with initials (users have no photos yet).
class UserAvatar extends StatelessWidget {
  final UserSummary? user;
  final double size;
  const UserAvatar(this.user, {super.key, this.size = 22});

  // Stable color per user, picked from the chart palette
  static const _palette = [
    Color(0xFF1F6FEB), Color(0xFF238636), Color(0xFF8957E5), Color(0xFFBF4B8A),
    Color(0xFFDB6D28), Color(0xFF0E8A9A), Color(0xFF9E6A03), Color(0xFFDA3633),
  ];

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.colors.border)),
        child: Icon(Icons.person_outline, size: size * 0.65, color: context.colors.mutedFg),
      );
    }
    final color = _palette[user!.username.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return Tooltip(
      message: user!.name,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: color,
        child: Text(initials(user!.name),
            style: TextStyle(fontSize: size * 0.4, color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Avatar + name in one row.
class UserLine extends StatelessWidget {
  final UserSummary? user;
  final String emptyText;
  const UserLine(this.user, {super.key, this.emptyText = 'Unassigned'});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        UserAvatar(user, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(user?.name ?? emptyText,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: user == null ? context.colors.mutedFg : null)),
        ),
      ]);
}

/// Project key in a monospace box, like "ERP".
class KeyBadge extends StatelessWidget {
  final String text;
  const KeyBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: context.colors.muted,
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

/// GitHub-style "Box": bordered container with an optional header row.
class Box extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const Box({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Container(
            color: c.muted,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              Expanded(child: Text(title!, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (trailing != null) trailing!,
            ]),
          ),
        if (title != null) const Divider(height: 1),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
}

/// Error message with a retry button.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 36, color: context.colors.danger),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Try again')),
            ],
          ]),
        ),
      );
}

/// Blank-slate message (no tickets, no notifications, …).
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyView({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: context.colors.mutedFg),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: TextStyle(color: context.colors.mutedFg), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}

/// Shows a snackbar message; red for errors.
void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            size: 18, color: error ? context.colors.danger : context.colors.success),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    ));
}

/// Thin progress bar with percentage (projects).
class ProgressLine extends StatelessWidget {
  final int percent;
  const ProgressLine(this.percent, {super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: percent / 100,
          minHeight: 8,
          color: context.colors.success,
          backgroundColor: context.colors.muted,
        ),
      );
}

/// Key/value row used in "properties" sidebars.
class PropRow extends StatelessWidget {
  final String label;
  final Widget value;
  final VoidCallback? onEdit;
  const PropRow(this.label, this.value, {super.key, this.onEdit});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(color: context.colors.mutedFg, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: value)),
          if (onEdit != null)
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(4),
              child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.settings_outlined, size: 16, color: context.colors.mutedFg)),
            ),
        ]),
      );
}

/// Width breakpoint: tablets / landscape get side-by-side layouts.
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;
