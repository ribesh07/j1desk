import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

/// Card shown in a Kanban column (same content as the web board card).
class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final bool showProject;
  final VoidCallback? onTap;
  final bool dragging;

  const TicketCard({super.key, required this.ticket, this.showProject = false, this.onTap, this.dragging = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = ticket;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(6),
      elevation: dragging ? 8 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: dragging ? c.link : c.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Key + type
            Row(children: [
              StatusIcon(t.status, size: 14),
              const SizedBox(width: 5),
              Text(showProject ? '${t.project.key} · ${t.key}' : t.key,
                  style: TextStyle(fontSize: 12, color: c.mutedFg, fontFamily: 'monospace')),
              const Spacer(),
              Icon(typeIcon(t.type), size: 14, color: c.mutedFg),
            ]),
            const SizedBox(height: 4),
            Text(t.title, style: const TextStyle(fontWeight: FontWeight.w500, height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis),
            if (t.labels.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: [for (final l in t.labels.take(4)) LabelChip(l)]),
            ],
            const SizedBox(height: 8),
            Row(children: [
              PriorityBadge(t.priority),
              const SizedBox(width: 6),
              if (t.dueDate != null)
                Flexible(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: t.isOverdue ? c.danger : c.mutedFg),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(formatDate(t.dueDate),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: t.isOverdue ? c.danger : c.mutedFg)),
                    ),
                  ]),
                ),
              const Spacer(),
              if (t.commentCount > 0) ...[
                Icon(Icons.chat_bubble_outline, size: 12, color: c.mutedFg),
                Text(' ${t.commentCount}  ', style: TextStyle(fontSize: 11.5, color: c.mutedFg)),
              ],
              UserAvatar(t.assignee, size: 20),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Row in ticket lists (GitHub issue list style).
class TicketTile extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback? onTap;
  const TicketTile({super.key, required this.ticket, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = ticket;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: StatusIcon(t.status)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                for (final l in t.labels) LabelChip(l),
              ]),
              const SizedBox(height: 4),
              Text(
                '${t.key} · ${t.project.name} · opened ${timeAgo(t.createdAt)} by ${t.creator.username}',
                style: TextStyle(fontSize: 12, color: c.mutedFg),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                StatusBadge(t.status),
                PriorityBadge(t.priority),
                if (t.dueDate != null)
                  Text(dueLabel(t.dueDate!),
                      style: TextStyle(fontSize: 12, color: t.isOverdue ? c.danger : c.mutedFg)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            UserAvatar(t.assignee, size: 22),
            if (t.commentCount > 0) ...[
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline, size: 13, color: c.mutedFg),
                Text(' ${t.commentCount}', style: TextStyle(fontSize: 12, color: c.mutedFg)),
              ]),
            ],
          ]),
        ]),
      ),
    );
  }
}
