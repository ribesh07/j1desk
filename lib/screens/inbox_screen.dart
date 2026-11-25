import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../cubits/data_cubit.dart';
import '../cubits/unread_cubit.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'ticket_detail_screen.dart';

/// Notifications inbox (same items that are sent as push notifications).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _unreadOnly = false;
  late final _cubit = DataCubit<List<AppNotification>>(_fetch)..load();

  Future<List<AppNotification>> _fetch() async {
    final res = await Api.notifications(unreadOnly: _unreadOnly);
    if (mounted) context.read<UnreadCubit>().set(res.unread); // keep the badge in sync
    return res.page.items;
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _open(AppNotification n) async {
    if (n.isUnread) {
      // Mark as read right away in the list, then on the server
      _cubit.set([for (final x in _cubit.state.data ?? <AppNotification>[]) x.id == n.id ? x.markRead() : x]);
      Api.markRead(n.id).then((_) {
        if (mounted) context.read<UnreadCubit>().refresh();
      }).catchError((_) {});
    }
    if (n.ticket != null) {
      await openTicket(context, n.ticket!.key);
      if (mounted) _cubit.load();
    }
  }

  Future<void> _markAll() async {
    try {
      await Api.markAllRead();
      if (!mounted) return;
      context.read<UnreadCubit>().reset();
      _cubit.load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unread = context.watch<UnreadCubit>().state;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(children: [
          SegmentedButton<bool>(
            segments: [
              const ButtonSegment(value: false, label: Text('All')),
              ButtonSegment(value: true, label: Text('Unread${unread > 0 ? ' ($unread)' : ''}')),
            ],
            selected: {_unreadOnly},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() => _unreadOnly = s.first);
              _cubit.load();
            },
          ),
          const Spacer(),
          if (unread > 0) TextButton.icon(onPressed: _markAll, icon: const Icon(Icons.done_all, size: 18), label: const Text('Mark all read')),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: BlocBuilder<DataCubit<List<AppNotification>>, DataState<List<AppNotification>>>(
          bloc: _cubit,
          builder: (context, s) {
            if (s.data == null && s.loading) return const LoadingView();
            if (s.data == null) return ErrorView(s.error ?? 'Error', onRetry: _cubit.load);
            if (s.data!.isEmpty) {
              return RefreshIndicator(
                onRefresh: _cubit.load,
                child: ListView(children: [
                  SizedBox(
                    height: 400,
                    child: EmptyView(
                      icon: Icons.inbox_outlined,
                      title: _unreadOnly ? "You're all caught up" : 'No notifications',
                      message: 'Assignments, status changes, comments and reminders show up here.',
                    ),
                  ),
                ]),
              );
            }
            return RefreshIndicator(
              onRefresh: _cubit.load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: s.data!.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = s.data![i];
                  return InkWell(
                    onTap: () => _open(n),
                    child: Container(
                      color: n.isUnread ? c.tone(Tone.blue).bg : null,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 8),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: n.isUnread ? c.link : Colors.transparent, shape: BoxShape.circle),
                          ),
                        ),
                        Icon(_icon(n.type), size: 18, color: c.mutedFg),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (n.ticket != null)
                              Text('${n.ticket!.key} · ${n.ticket!.title}', style: TextStyle(fontSize: 12, color: c.mutedFg), overflow: TextOverflow.ellipsis),
                            Text(n.title, style: TextStyle(fontWeight: n.isUnread ? FontWeight.w600 : FontWeight.w400)),
                            if (n.body != null && n.body!.isNotEmpty)
                              Text(n.body!, style: TextStyle(fontSize: 13, color: c.mutedFg), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(timeAgo(n.createdAt), style: TextStyle(fontSize: 12, color: c.mutedFg)),
                          const SizedBox(height: 6),
                          if (n.actor != null) UserAvatar(n.actor, size: 20),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }

  IconData _icon(String type) => switch (type) {
        'ASSIGNED' || 'REASSIGNED' => Icons.person_add_alt,
        'UNASSIGNED' => Icons.person_remove_outlined,
        'STATUS_CHANGED' => Icons.sync,
        'COMMENTED' => Icons.chat_bubble_outline,
        'MENTIONED' => Icons.alternate_email,
        'REVIEW_REQUESTED' => Icons.visibility_outlined,
        'APPROVED' => Icons.check_circle_outline,
        'CHANGES_REQUESTED' => Icons.change_circle_outlined,
        'REJECTED' => Icons.cancel_outlined,
        'REOPENED' => Icons.replay,
        'DUE_SOON' => Icons.event_outlined,
        'OVERDUE' => Icons.schedule,
        _ => Icons.notifications_none,
      };
}
