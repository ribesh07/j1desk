import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../cubits/data_cubit.dart';
import '../models/models.dart';
import '../widgets/activity_tile.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'ticket_form_screen.dart';

/// Opens a ticket by key (e.g. "ERP-001"). Returns when the user goes back.
Future<void> openTicket(BuildContext context, String key) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketKey: key)));

/// Ticket page: workflow actions, properties, description, relations, attachments,
/// and the conversation (comments / activity / assignment history).
class TicketDetailScreen extends StatelessWidget {
  final String ticketKey;
  const TicketDetailScreen({super.key, required this.ticketKey});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => DataCubit<TicketDetail>(() => Api.ticket(ticketKey))..load()),
        BlocProvider(create: (_) => DataCubit<List<Comment>>(() => Api.comments(ticketKey))..load()),
        BlocProvider(create: (_) => DataCubit<List<Activity>>(() => Api.ticketActivity(ticketKey))..load()),
        BlocProvider(create: (_) => DataCubit<List<Assignment>>(() => Api.assignments(ticketKey))..load()),
      ],
      child: _TicketView(ticketKey: ticketKey),
    );
  }
}

class _TicketView extends StatefulWidget {
  final String ticketKey;
  const _TicketView({required this.ticketKey});

  @override
  State<_TicketView> createState() => _TicketViewState();
}

class _TicketViewState extends State<_TicketView> {
  bool _busy = false;
  int _tab = 0; // 0 comments, 1 activity, 2 assignments
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  /// Reloads the ticket and its timeline after any change.
  Future<void> _reloadAll() async {
    await Future.wait([
      context.read<DataCubit<TicketDetail>>().load(),
      context.read<DataCubit<List<Comment>>>().load(),
      context.read<DataCubit<List<Activity>>>().load(),
      context.read<DataCubit<List<Assignment>>>().load(),
    ]);
  }

  /// Runs an API action with a busy flag, shows the result and reloads.
  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (success != null) showMessage(context, success);
      await _reloadAll();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Actions ─────────────────────────────────────────────────

  /// Workflow button: asks for a reason / confirmation when needed, then changes the status.
  /// The server notifies the whole team by push after the change.
  Future<void> _transition(TicketDetail d, TransitionOption t) async {
    final toLabel = metaOf(statusMeta, t.to).label;
    String? reason;
    if (t.requiresReason) {
      reason = await askReason(context, title: '${t.label} — ${d.ticket.key}', description: 'Moving to $toLabel requires a reason.', confirmLabel: t.label);
      if (reason == null) return;
    } else if (t.confirm) {
      if (!await confirm(context, title: '${t.label}?', message: '${d.ticket.key} will move to $toLabel.', confirmLabel: t.label)) return;
    }
    await _run(() => Api.changeStatus(d.ticket.key, t.to, reason: reason), success: '${d.ticket.key} moved to $toLabel · team notified');
  }

  Future<void> _assign(TicketDetail d) async {
    final pick = await pickUser(context, projectId: d.ticket.project.id, selectedId: d.ticket.assignee?.id);
    if (pick == null) return;
    await _run(() => Api.assignTicket(d.ticket.key, pick.user?.id),
        success: pick.user == null ? 'Ticket unassigned' : 'Assigned to ${pick.user!.name}');
  }

  Future<void> _setReviewer(TicketDetail d) async {
    final pick = await pickUser(context, projectId: d.ticket.project.id, title: 'Reviewer', selectedId: d.reviewer?.id);
    if (pick == null) return;
    await _run(() => Api.updateTicket(d.ticket.key, {'reviewerId': pick.user?.id}), success: 'Reviewer updated');
  }

  Future<void> _setPriority(TicketDetail d) async {
    final v = await pickOption(context, title: 'Priority', options: priorityMeta.map((k, m) => MapEntry(k, m.label)), selected: d.ticket.priority);
    if (v == null || v == d.ticket.priority) return;
    await _run(() => Api.updateTicket(d.ticket.key, {'priority': v}), success: 'Priority updated');
  }

  Future<void> _setType(TicketDetail d) async {
    final v = await pickOption(context, title: 'Type', options: typeMeta.map((k, m) => MapEntry(k, m.label)), selected: d.ticket.type);
    if (v == null || v == d.ticket.type) return;
    await _run(() => Api.updateTicket(d.ticket.key, {'type': v}), success: 'Type updated');
  }

  Future<void> _setDueDate(TicketDetail d) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: d.ticket.dueDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      helpText: 'Due date',
      cancelText: d.ticket.dueDate != null ? 'Cancel' : null,
    );
    if (date == null) return;
    await _run(() => Api.updateTicket(d.ticket.key, {'dueDate': apiDate(date)}), success: 'Due date updated');
  }

  Future<void> _upload(TicketDetail d) async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final list = <({String name, Uint8List bytes})>[];
    for (final f in files) {
      list.add((name: f.name, bytes: await f.readAsBytes()));
    }
    await _run(() => Api.uploadAttachments(d.ticket.key, list), success: '${list.length} file(s) uploaded');
  }

  /// Downloads the attachment (with the auth token) into the cache and opens it.
  Future<void> _openAttachment(Attachment a) async {
    try {
      showMessage(context, 'Downloading ${a.fileName}…');
      final bytes = await Api.downloadAttachment(a);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${a.id}_${a.fileName}');
      await file.writeAsBytes(bytes);
      final result = await OpenFilex.open(file.path, type: a.mimeType);
      if (result.type != ResultType.done && mounted) showMessage(context, result.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _addLink(TicketDetail d) async {
    final key = TextEditingController();
    String type = 'RELATES_TO';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Link a ticket', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              items: [for (final e in linkTypeLabels.entries) DropdownMenuItem(value: e.key, child: Text('This ticket ${e.value}'))],
              onChanged: (v) => setLocal(() => type = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: key,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'Ticket ID, e.g. ERP-012'),
            ),
          ]),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add link')),
          ],
        ),
      ),
    );
    if (ok != true || key.text.trim().isEmpty) return;
    await _run(() => Api.addLink(d.ticket.key, key.text.trim().toUpperCase(), type), success: 'Link added');
  }

  Future<void> _sendComment(TicketDetail d) async {
    final body = _comment.text.trim();
    if (body.isEmpty) return;
    await _run(() async {
      await Api.addComment(d.ticket.key, body);
      _comment.clear();
    });
  }

  Future<void> _editComment(TicketDetail d, Comment cm) async {
    final ctrl = TextEditingController(text: cm.body);
    final body = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit comment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: TextField(controller: ctrl, minLines: 3, maxLines: 8, autofocus: true),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (body == null || body.isEmpty || body == cm.body) return;
    await _run(() => Api.editComment(d.ticket.key, cm.id, body), success: 'Comment updated');
  }

  Future<void> _menu(TicketDetail d, String action) async {
    switch (action) {
      case 'edit':
        final saved = await openTicketForm(context, existing: d);
        if (saved == true) _reloadAll();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: d.ticket.key));
        if (mounted) showMessage(context, 'Copied ${d.ticket.key}');
      case 'archive':
        if (!await confirm(context, title: 'Archive ${d.ticket.key}?', message: 'The ticket is hidden from boards and lists. History is kept and it can be restored.', confirmLabel: 'Archive', danger: true)) return;
        await _run(() => Api.archiveTicket(d.ticket.key), success: 'Ticket archived');
      case 'restore':
        await _run(() => Api.restoreTicket(d.ticket.key), success: 'Ticket restored');
    }
  }

  // ── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DataCubit<TicketDetail>>().state;
    final d = state.data;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticketKey, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
        actions: [
          if (d != null)
            PopupMenuButton<String>(
              onSelected: (a) => _menu(d, a),
              itemBuilder: (_) => [
                if (d.canEdit && d.deletedAt == null) const PopupMenuItem(value: 'edit', child: Text('Edit ticket')),
                const PopupMenuItem(value: 'copy', child: Text('Copy ticket ID')),
                if (d.canArchive && d.deletedAt == null) const PopupMenuItem(value: 'archive', child: Text('Archive')),
                if (d.deletedAt != null) const PopupMenuItem(value: 'restore', child: Text('Restore')),
              ],
            ),
        ],
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: () {
        if (d == null && state.loading) return const LoadingView();
        if (d == null) return ErrorView(state.error ?? 'Ticket not found', onRetry: _reloadAll);
        final wide = isWide(context);
        final main = _main(d);
        final side = _properties(d);
        return RefreshIndicator(
          onRefresh: _reloadAll,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(d),
              const SizedBox(height: 16),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: main)),
                  const SizedBox(width: 24),
                  SizedBox(width: 300, child: side),
                ])
              else ...[
                // Phones: content first, then properties, then the rest
                ...main.take(2),
                side,
                const SizedBox(height: 16),
                ...main.skip(2),
              ],
            ],
          ),
        );
      }(),
    );
  }

  Widget _header(TicketDetail d) {
    final c = context.colors;
    final t = d.ticket;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: t.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
        TextSpan(text: '  ${t.key}', style: TextStyle(fontSize: 22, color: c.mutedFg, fontWeight: FontWeight.w300)),
      ])),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        StatusBadge(t.status),
        if (d.deletedAt != null) const ToneBadge(text: 'Archived', tone: Tone.gray, icon: Icons.archive_outlined),
        Text('${t.creator.name} opened ${timeAgo(t.createdAt)} · ${t.project.name}', style: TextStyle(color: c.mutedFg, fontSize: 13)),
      ]),
      const SizedBox(height: 12),
      _workflow(d),
      const Divider(height: 28),
    ]);
  }

  /// Workflow buttons from permissions.transitions (only the actions this user may do).
  Widget _workflow(TicketDetail d) {
    final c = context.colors;
    if (d.deletedAt != null) return const SizedBox.shrink();
    final buttons = <Widget>[
      for (final (i, t) in d.transitions.indexed)
        i == 0 && !t.requiresReason
            ? FilledButton(onPressed: _busy ? null : () => _transition(d, t), child: Text(t.label))
            : OutlinedButton(onPressed: _busy ? null : () => _transition(d, t), child: Text(t.label)),
      if (d.canAssign)
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _assign(d),
          icon: const Icon(Icons.person_add_alt, size: 16),
          label: Text(d.ticket.assignee == null ? 'Assign' : 'Reassign'),
        ),
    ];
    if (buttons.isEmpty) {
      return Text('No workflow actions available to you on this ticket.', style: TextStyle(color: c.mutedFg, fontSize: 13));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  /// Main column: description, relations, attachments, conversation.
  List<Widget> _main(TicketDetail d) {
    final c = context.colors;
    return [
      Box(
        title: 'Description',
        child: Text(
          (d.description ?? '').isEmpty ? 'No description provided.' : d.description!,
          style: TextStyle(height: 1.5, color: (d.description ?? '').isEmpty ? c.mutedFg : null),
        ),
      ),
      const SizedBox(height: 16),
      if (d.parent != null || d.subtasks.isNotEmpty || d.links.isNotEmpty || d.canEdit) ...[
        Box(
          title: 'Relations',
          trailing: d.canEdit ? _smallButton(Icons.add_link, 'Link', () => _addLink(d)) : null,
          padding: EdgeInsets.zero,
          child: Column(children: [
            if (d.parent != null) _refTile('Parent', d.parent!),
            for (final s in d.subtasks) _refTile('Subtask', s),
            for (final l in d.links)
              _refTile(
                l.direction == 'outgoing' ? linkTypeLabels[l.type] ?? l.type : '${linkTypeLabels[l.type] ?? l.type} (incoming)',
                l.ticket,
                onRemove: d.canEdit ? () => _run(() => Api.removeLink(d.ticket.key, l.id), success: 'Link removed') : null,
              ),
            if (d.parent == null && d.subtasks.isEmpty && d.links.isEmpty)
              Padding(padding: const EdgeInsets.all(12), child: Text('No related tickets', style: TextStyle(color: c.mutedFg))),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      Box(
        title: 'Attachments (${d.attachments.length})',
        trailing: d.canUpload ? _smallButton(Icons.upload_file, 'Upload', () => _upload(d)) : null,
        padding: EdgeInsets.zero,
        child: d.attachments.isEmpty
            ? Padding(padding: const EdgeInsets.all(12), child: Text('No files attached', style: TextStyle(color: c.mutedFg)))
            : Column(children: [
                for (final a in d.attachments)
                  ListTile(
                    leading: Icon(a.mimeType.startsWith('image/') ? Icons.image_outlined : Icons.insert_drive_file_outlined),
                    title: Text(a.fileName, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${fileSize(a.size)} · ${a.uploader.name} · ${timeAgo(a.createdAt)}'),
                    onTap: () => _openAttachment(a),
                    trailing: a.canDelete
                        ? IconButton(
                            tooltip: 'Delete',
                            icon: Icon(Icons.delete_outline, size: 18, color: c.danger),
                            onPressed: () async {
                              if (await confirm(context, title: 'Delete ${a.fileName}?', confirmLabel: 'Delete', danger: true)) {
                                _run(() => Api.deleteAttachment(a.id), success: 'Attachment deleted');
                              }
                            },
                          )
                        : null,
                  ),
              ]),
      ),
      const SizedBox(height: 20),
      _conversation(d),
    ];
  }

  Widget _smallButton(IconData icon, String label, VoidCallback onTap) => TextButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      );

  Widget _refTile(String relation, TicketRef r, {VoidCallback? onRemove}) => ListTile(
        leading: r.status != null ? StatusIcon(r.status!) : null,
        title: Text('${r.key}  ${r.title}', overflow: TextOverflow.ellipsis),
        subtitle: Text(relation),
        onTap: () => openTicket(context, r.key),
        trailing: onRemove == null ? null : IconButton(icon: const Icon(Icons.link_off, size: 18), tooltip: 'Remove link', onPressed: onRemove),
      );

  /// Properties box (right sidebar on tablets).
  Widget _properties(TicketDetail d) {
    final c = context.colors;
    final t = d.ticket;
    final edit = d.canEdit && d.deletedAt == null;
    return Box(
      title: 'Properties',
      child: Column(children: [
        PropRow('Assignee', UserLine(t.assignee), onEdit: d.canAssign && d.deletedAt == null ? () => _assign(d) : null),
        PropRow('Reviewer', UserLine(d.reviewer, emptyText: 'No reviewer'), onEdit: edit ? () => _setReviewer(d) : null),
        PropRow('Status', StatusBadge(t.status)),
        PropRow('Priority', PriorityBadge(t.priority), onEdit: edit ? () => _setPriority(d) : null),
        PropRow(
          'Type',
          Row(children: [Icon(typeIcon(t.type), size: 16, color: c.mutedFg), const SizedBox(width: 6), Text(metaOf(typeMeta, t.type).label)]),
          onEdit: edit ? () => _setType(d) : null,
        ),
        PropRow(
          'Labels',
          t.labels.isEmpty
              ? Text('None', style: TextStyle(color: c.mutedFg))
              : Wrap(spacing: 4, runSpacing: 4, children: [for (final l in t.labels) LabelChip(l)]),
        ),
        PropRow(
          'Due date',
          t.dueDate == null
              ? Text('No due date', style: TextStyle(color: c.mutedFg))
              : Text('${formatDate(t.dueDate)} · ${dueLabel(t.dueDate!)}', style: TextStyle(color: t.isOverdue ? c.danger : null)),
          onEdit: edit ? () => _setDueDate(d) : null,
        ),
        PropRow('Estimate', Text(d.estimateHours == null ? '—' : '${d.estimateHours}h')),
        PropRow('Actual', Text(d.actualHours == null ? '—' : '${d.actualHours}h')),
        PropRow('Project', Row(children: [KeyBadge(t.project.key), const SizedBox(width: 6), Flexible(child: Text(t.project.name, overflow: TextOverflow.ellipsis))])),
        PropRow('Team', Text(d.team?.name ?? '—')),
        PropRow('Created', Text(formatDateTime(t.createdAt))),
        if (d.resolvedAt != null) PropRow('Resolved', Text(formatDateTime(d.resolvedAt!))),
        if (d.closedAt != null) PropRow('Closed', Text(formatDateTime(d.closedAt!))),
      ]),
    );
  }

  /// Comments / Activity / Assignments tabs.
  Widget _conversation(TicketDetail d) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, icon: Icon(Icons.chat_bubble_outline, size: 16), label: Text('Comments')),
          ButtonSegment(value: 1, icon: Icon(Icons.history, size: 16), label: Text('Activity')),
          ButtonSegment(value: 2, icon: Icon(Icons.people_outline, size: 16), label: Text('Assignees')),
        ],
        selected: {_tab},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _tab = s.first),
      ),
      const SizedBox(height: 12),
      if (_tab == 0) ...[
        ..._comments(d),
        if (d.canComment && d.deletedAt == null) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(hintText: 'Leave a comment (use @username to mention someone)'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _busy ? null : () => _sendComment(d), child: const Text('Comment')),
          ),
        ],
      ],
      if (_tab == 1)
        BlocBuilder<DataCubit<List<Activity>>, DataState<List<Activity>>>(
          builder: (context, s) => s.data == null
              ? const Padding(padding: EdgeInsets.all(20), child: LoadingView())
              : Column(children: [for (final a in s.data!) ActivityTile(a)]),
        ),
      if (_tab == 2)
        BlocBuilder<DataCubit<List<Assignment>>, DataState<List<Assignment>>>(
          builder: (context, s) {
            if (s.data == null) return const Padding(padding: EdgeInsets.all(20), child: LoadingView());
            if (s.data!.isEmpty) return Padding(padding: const EdgeInsets.all(12), child: Text('Never assigned', style: TextStyle(color: c.mutedFg)));
            return Column(children: [
              for (final a in s.data!)
                ListTile(
                  leading: UserAvatar(a.to, size: 28),
                  title: Text(a.to == null
                      ? '${a.assignedBy.name} unassigned ${a.from?.name ?? ''}'
                      : a.from == null
                          ? '${a.assignedBy.name} assigned ${a.to!.name}'
                          : '${a.assignedBy.name} reassigned ${a.from!.name} → ${a.to!.name}'),
                  subtitle: Text([timeAgo(a.createdAt), if (a.reason != null) a.reason!].join(' · ')),
                ),
            ]);
          },
        ),
    ]);
  }

  List<Widget> _comments(TicketDetail d) {
    final c = context.colors;
    final s = context.watch<DataCubit<List<Comment>>>().state;
    if (s.data == null) return [const Padding(padding: EdgeInsets.all(20), child: LoadingView())];
    if (s.data!.isEmpty) return [Padding(padding: const EdgeInsets.all(8), child: Text('No comments yet', style: TextStyle(color: c.mutedFg)))];
    return [
      for (final cm in s.data!)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            UserAvatar(cm.author, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Box(
                title: '${cm.author.name} · ${timeAgo(cm.createdAt)}${cm.editedAt != null ? ' · edited' : ''}',
                trailing: cm.canEdit || cm.canDelete
                    ? PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_horiz, size: 18, color: c.mutedFg),
                        onSelected: (a) async {
                          if (a == 'edit') return _editComment(d, cm);
                          if (await confirm(context, title: 'Delete comment?', confirmLabel: 'Delete', danger: true)) {
                            _run(() => Api.deleteComment(d.ticket.key, cm.id), success: 'Comment deleted');
                          }
                        },
                        itemBuilder: (_) => [
                          if (cm.canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          if (cm.canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      )
                    : null,
                child: SelectableText(cm.body, style: const TextStyle(height: 1.45)),
              ),
            ),
          ]),
        ),
    ];
  }
}
