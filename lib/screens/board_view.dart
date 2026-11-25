import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/board_cubit.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/ticket_card.dart';
import 'ticket_detail_screen.dart';
import 'ticket_form_screen.dart';

/// Kanban board with drag & drop between status columns.
///
/// Long-press a card to pick it up, drag it over another column (the board scrolls
/// sideways near the screen edges) and drop it. Columns you may move to are highlighted.
/// The move follows the same workflow as the web app: reason / confirm dialogs, the
/// assign sheet for "Assigned", optimistic update + rollback on error.
/// Needs a [BoardCubit] above it.
class BoardView extends StatefulWidget {
  final bool showProject;

  /// Project for the "+" buttons on Backlog / New columns (null → choose in the form)
  final String? projectId;

  const BoardView({super.key, this.showProject = false, this.projectId});

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  final _hScroll = ScrollController();
  Ticket? _dragging; // card being dragged
  Set<String> _allowed = {}; // columns the dragged card may move to
  String? _hoverColumn; // drop preview
  int? _hoverIndex;
  final Set<String> _hidden = {'REJECTED'}; // hidden columns (same default as the web)
  bool _hideEmpty = false;

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  // ── Drag lifecycle ───────────────────────────────────────────

  void _startDrag(Ticket t) {
    final user = context.read<AuthCubit>().user;
    setState(() {
      _dragging = t;
      _allowed = allowedTargets(
        status: t.status,
        assigneeId: t.assignee?.id,
        creatorId: t.creator.id,
        userId: user.id,
        isManager: user.isManager,
      );
    });
  }

  void _endDrag() => setState(() {
        _dragging = null;
        _hoverColumn = null;
        _hoverIndex = null;
      });

  /// Scrolls the board sideways while the finger is near the left / right edge.
  void _autoScroll(DragUpdateDetails d) {
    if (!_hScroll.hasClients) return;
    final width = MediaQuery.sizeOf(context).width;
    const edge = 56.0, step = 14.0;
    final pos = _hScroll.position;
    if (d.globalPosition.dx > width - edge && pos.pixels < pos.maxScrollExtent) {
      _hScroll.jumpTo((pos.pixels + step).clamp(0, pos.maxScrollExtent));
    } else if (d.globalPosition.dx < edge && pos.pixels > 0) {
      _hScroll.jumpTo((pos.pixels - step).clamp(0, pos.maxScrollExtent));
    }
  }

  // ── Drop: same rules as the web board (src/features/board/board.tsx) ──

  Future<void> _drop(Ticket ticket, String to, int index) async {
    _endDrag();
    final cubit = context.read<BoardCubit>();
    final user = context.read<AuthCubit>().user;

    // Same column → just reorder
    if (to == ticket.status) {
      final current = cubit.state.columns[to]!.indexWhere((t) => t.id == ticket.id);
      if (current == index || current + 1 == index) return; // dropped in place
      final adjusted = index > current ? index - 1 : index; // list without the card
      final error = await cubit.move(ticket, to, adjusted);
      if (error != null && mounted) showMessage(context, error, error: true);
      return;
    }

    final from = metaOf(statusMeta, ticket.status).label;
    final toLabel = metaOf(statusMeta, to).label;

    // Dropping on "Assigned" from New/Backlog/Rejected = choose an assignee
    if (to == 'ASSIGNED' && ['NEW', 'BACKLOG', 'REJECTED'].contains(ticket.status) &&
        (ticket.assignee == null || ticket.status == 'REJECTED')) {
      if (!user.isManager) return showMessage(context, 'Only team leaders and admins can assign tickets', error: true);
      return _assign(ticket);
    }

    final rule = findDefinition(ticket.status, to);
    if (rule == null) {
      return showMessage(context, "Can't move ${ticket.key} from $from to $toLabel. Use the actions on the ticket to follow the workflow.",
          error: true);
    }

    String? reason;
    if (rule.requiresReason) {
      reason = await askReason(context,
          title: '${rule.label} — ${ticket.key}', description: 'Moving to $toLabel requires a reason.', confirmLabel: rule.label);
      if (reason == null) return;
    } else if (rule.confirm) {
      final ok = await confirm(context, title: '${rule.label}?', message: '${ticket.key} will move to $toLabel.', confirmLabel: rule.label);
      if (!ok) return;
    }

    final error = await cubit.move(ticket, to, index, reason: reason);
    if (!mounted) return;
    if (error != null) {
      showMessage(context, error, error: true);
    } else {
      showMessage(context, '${ticket.key} moved to $toLabel · team notified');
    }
  }

  Future<void> _assign(Ticket ticket) async {
    final pick = await pickUser(context, projectId: ticket.project.id, allowNone: false);
    if (pick?.user == null || !mounted) return;
    try {
      await Api.assignTicket(ticket.key, pick!.user!.id);
      if (!mounted) return;
      showMessage(context, '${ticket.key} assigned to ${pick.user!.name}');
      context.read<BoardCubit>().load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  // ── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BoardCubit, BoardState>(
      builder: (context, state) {
        if (state.loading && state.tickets.isEmpty) return const LoadingView();
        if (state.error != null && state.tickets.isEmpty) {
          return ErrorView(state.error!, onRetry: () => context.read<BoardCubit>().load());
        }
        final columns = state.columns;
        final visible = boardColumns
            .where((s) => !_hidden.contains(s))
            .where((s) => !_hideEmpty || columns[s]!.isNotEmpty || _allowed.contains(s) && _dragging != null)
            .toList();
        final screen = MediaQuery.sizeOf(context).width;
        final colWidth = screen < 600 ? (screen * 0.82).clamp(250.0, 320.0) : 290.0;

        return Column(children: [
          _toolbar(state, columns),
          if (state.loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: visible.isEmpty
                ? const EmptyView(icon: Icons.view_column_outlined, title: 'All columns are hidden', message: 'Use “Columns” to show them.')
                : ListView.separated(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => SizedBox(width: colWidth, child: _column(visible[i], columns[visible[i]]!)),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _toolbar(BoardState state, Map<String, List<Ticket>> columns) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 2),
      child: Row(children: [
        Expanded(
          child: Text(
            '${state.total} ticket${state.total == 1 ? '' : 's'} · long-press a card to drag',
            style: TextStyle(fontSize: 12, color: c.mutedFg),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Visible columns',
          onSelected: (s) => setState(() {
            if (s == '_empty') {
              _hideEmpty = !_hideEmpty;
            } else if (s == '_all') {
              _hidden.clear();
            } else if (!_hidden.remove(s)) {
              _hidden.add(s);
            }
          }),
          itemBuilder: (_) => [
            for (final s in boardColumns)
              CheckedPopupMenuItem(
                value: s,
                checked: !_hidden.contains(s),
                child: Text('${metaOf(statusMeta, s).label}  (${columns[s]!.length})'),
              ),
            const PopupMenuDivider(),
            CheckedPopupMenuItem(value: '_empty', checked: _hideEmpty, child: const Text('Hide empty columns')),
            if (_hidden.isNotEmpty) const PopupMenuItem(value: '_all', child: Text('Show all columns')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              Icon(Icons.view_column_outlined, size: 18, color: c.mutedFg),
              const SizedBox(width: 4),
              Text('Columns', style: TextStyle(color: c.mutedFg, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }

  /// One status column: header + cards. The whole column is a drop target (append at the end);
  /// each card is also a target (insert before that card).
  Widget _column(String status, List<Ticket> tickets) {
    final c = context.colors;
    final meta = metaOf(statusMeta, status);
    final dragging = _dragging != null;
    final isOrigin = dragging && _dragging!.status == status;
    final valid = dragging && _allowed.contains(status);
    final hovering = _hoverColumn == status;

    // Column frame color hints where the card can go
    Color border = c.border;
    if (dragging && valid) border = c.success;
    if (dragging && hovering) border = valid || isOrigin ? c.link : c.danger;

    return DragTarget<Ticket>(
      onWillAcceptWithDetails: (d) {
        setState(() {
          _hoverColumn = status;
          _hoverIndex = tickets.length;
        });
        return true;
      },
      onLeave: (_) => setState(() {
        if (_hoverColumn == status) _hoverColumn = null;
      }),
      onAcceptWithDetails: (d) => _drop(d.data, status, tickets.length),
      builder: (context, _, _) => AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: dragging && !valid && !isOrigin ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: c.muted,
            border: Border.all(color: border, width: dragging && (valid || hovering) ? 1.5 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
              child: Row(children: [
                StatusIcon(status),
                const SizedBox(width: 6),
                Text(meta.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                  child: Text('${tickets.length}', style: TextStyle(fontSize: 12, color: c.mutedFg)),
                ),
                const Spacer(),
                if (status == 'BACKLOG' || status == 'NEW')
                  IconButton(
                    tooltip: 'Add ticket',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.add, size: 18, color: c.mutedFg),
                    onPressed: () async {
                      final created = await openTicketForm(context, projectId: widget.projectId, status: status);
                      if (created == true && context.mounted) context.read<BoardCubit>().load();
                    },
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(statusDescriptions[status] ?? '', style: TextStyle(fontSize: 11.5, color: c.mutedFg)),
              ),
            ),
            // Cards
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => context.read<BoardCubit>().load(),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: tickets.length + 1,
                  itemBuilder: (context, i) {
                    if (i == tickets.length) {
                      // Space at the bottom: drop indicator for "append" + empty hint
                      return Column(children: [
                        if (hovering && _hoverIndex == tickets.length) const _DropLine(),
                        if (tickets.isEmpty && !hovering)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(dragging ? 'Drop here' : 'No tickets', style: TextStyle(color: c.mutedFg, fontSize: 12)),
                          ),
                        const SizedBox(height: 60),
                      ]);
                    }
                    return _card(status, tickets, i);
                  },
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _card(String status, List<Ticket> tickets, int index) {
    final t = tickets[index];
    final card = TicketCard(ticket: t, showProject: widget.showProject, onTap: () => openTicket(context, t.key));
    return DragTarget<Ticket>(
      onWillAcceptWithDetails: (d) {
        setState(() {
          _hoverColumn = status;
          _hoverIndex = index;
        });
        return d.data.id != t.id;
      },
      onAcceptWithDetails: (d) => _drop(d.data, status, index),
      builder: (context, _, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(children: [
          if (_hoverColumn == status && _hoverIndex == index && _dragging?.id != t.id) const _DropLine(),
          LayoutBuilder(
            builder: (context, box) => LongPressDraggable<Ticket>(
              data: t,
              delay: const Duration(milliseconds: 250),
              hapticFeedbackOnStart: true,
              onDragStarted: () => _startDrag(t),
              onDragUpdate: _autoScroll,
              onDragEnd: (_) => _endDrag(),
              onDraggableCanceled: (_, _) => _endDrag(),
              // The card that follows the finger
              feedback: Transform.rotate(
                angle: 0.03,
                child: SizedBox(width: box.maxWidth, child: TicketCard(ticket: t, showProject: widget.showProject, dragging: true)),
              ),
              childWhenDragging: Opacity(opacity: 0.35, child: card),
              child: card,
            ),
          ),
        ]),
      ),
    );
  }
}

/// Blue line showing where the card will land.
class _DropLine extends StatelessWidget {
  const _DropLine();

  @override
  Widget build(BuildContext context) => Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(color: context.colors.link, borderRadius: BorderRadius.circular(2)),
      );
}
