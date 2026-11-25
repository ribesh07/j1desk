import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

IconData activityIcon(String type) => switch (type) {
      'CREATED' => Icons.add_circle_outline,
      'UPDATED' => Icons.edit_outlined,
      'STATUS_CHANGED' => Icons.sync,
      'ASSIGNED' => Icons.person_add_alt,
      'UNASSIGNED' => Icons.person_remove_outlined,
      'REVIEWER_CHANGED' => Icons.visibility_outlined,
      'PRIORITY_CHANGED' => Icons.signal_cellular_alt,
      'DUE_DATE_CHANGED' => Icons.event_outlined,
      'LABELS_CHANGED' => Icons.sell_outlined,
      'COMMENTED' => Icons.chat_bubble_outline,
      'ATTACHMENT_ADDED' || 'ATTACHMENT_REMOVED' => Icons.attach_file,
      'LINKED' => Icons.link,
      'UNLINKED' => Icons.link_off,
      'ARCHIVED' => Icons.archive_outlined,
      'RESTORED' => Icons.unarchive_outlined,
      _ => Icons.circle_outlined,
    };

String _status(String? s) => s == null ? '' : metaOf(statusMeta, s).label;

/// Human sentence for an activity entry, without the actor (same text as the web app).
String describeActivity(Activity a) => switch (a.type) {
      'CREATED' => 'created this ticket',
      'STATUS_CHANGED' => a.fromValue != null
          ? 'changed status from ${_status(a.fromValue)} to ${_status(a.toValue)}'
          : 'changed status to ${_status(a.toValue)}',
      'ASSIGNED' => a.fromValue != null ? 'reassigned from ${a.fromValue} to ${a.toValue}' : 'assigned ${a.toValue}',
      'UNASSIGNED' => 'unassigned ${a.fromValue ?? ''}',
      'REVIEWER_CHANGED' => a.toValue != null ? 'set ${a.toValue} as reviewer' : 'removed reviewer ${a.fromValue ?? ''}',
      'PRIORITY_CHANGED' => 'changed priority from ${metaOf(priorityMeta, a.fromValue ?? '').label} to ${metaOf(priorityMeta, a.toValue ?? '').label}',
      'DUE_DATE_CHANGED' => a.toValue != null ? 'set the due date to ${formatDate(DateTime.tryParse(a.toValue!))}' : 'removed the due date',
      'LABELS_CHANGED' => a.toValue != null && a.toValue!.isNotEmpty ? 'changed labels to ${a.toValue}' : 'removed all labels',
      'COMMENTED' => 'commented',
      'ATTACHMENT_ADDED' => 'attached ${a.toValue ?? 'a file'}',
      'ATTACHMENT_REMOVED' => 'removed attachment ${a.fromValue ?? ''}',
      'LINKED' => 'linked this ticket: ${linkTypeLabels[a.message] ?? 'relates to'} ${a.toValue ?? ''}',
      'UNLINKED' => 'removed link to ${a.fromValue ?? ''}',
      'ARCHIVED' => 'archived this ticket',
      'RESTORED' => 'restored this ticket',
      _ => 'updated this ticket',
    };

/// One line of an activity timeline: icon, "actor + what happened", time and optional reason.
class ActivityTile extends StatelessWidget {
  final Activity activity;
  final bool showTicket;
  final VoidCallback? onTap;

  const ActivityTile(this.activity, {super.key, this.showTicket = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = activity;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: c.muted, shape: BoxShape.circle, border: Border.all(color: c.border)),
            child: Icon(activityIcon(a.type), size: 15, color: c.mutedFg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: a.actor.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: ' ${describeActivity(a)}', style: TextStyle(color: c.mutedFg)),
                if (showTicket && a.ticket != null)
                  TextSpan(text: ' · ${a.ticket!.key} ${a.ticket!.title}', style: TextStyle(color: c.link)),
              ])),
              if (a.type == 'STATUS_CHANGED' && a.toValue != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  if (a.fromValue != null) ...[StatusBadge(a.fromValue!), Icon(Icons.arrow_right_alt, size: 16, color: c.mutedFg)],
                  StatusBadge(a.toValue!),
                ]),
              ],
              if (a.message != null && a.message!.isNotEmpty && a.type != 'LINKED' && a.type != 'UNLINKED') ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: c.muted, borderRadius: BorderRadius.circular(6), border: Border.all(color: c.border)),
                  child: Text(a.message!, style: const TextStyle(fontSize: 13)),
                ),
              ],
              const SizedBox(height: 2),
              Text(timeAgo(a.createdAt), style: TextStyle(fontSize: 11.5, color: c.mutedFg)),
            ]),
          ),
        ]),
      ),
    );
  }
}
