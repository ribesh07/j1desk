import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/meta.dart';
import '../core/theme.dart';
import '../cubits/board_cubit.dart';
import '../cubits/data_cubit.dart';
import '../cubits/ticket_list_cubit.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/ticket_card.dart';
import 'board_view.dart';
import 'ticket_detail_screen.dart';
import 'ticket_form_screen.dart';

/// Tickets with filters and a List / Board switch.
/// Used for "All Tickets", "My Tasks" (baseFilters: assigneeId=me) and inside a project.
class TicketsView extends StatefulWidget {
  /// Fixed filters that the user can't remove, e.g. {'assigneeId': 'me'} or {'projectId': 'ERP'}
  final Map<String, dynamic> baseFilters;
  final bool startWithBoard;
  final bool showProjectFilter;

  const TicketsView({super.key, this.baseFilters = const {}, this.startWithBoard = false, this.showProjectFilter = true});

  @override
  State<TicketsView> createState() => _TicketsViewState();
}

class _TicketsViewState extends State<TicketsView> {
  late bool _board = widget.startWithBoard;
  final _search = TextEditingController();
  String _q = '';
  Set<String> _statuses = {};
  Set<String> _priorities = {};
  String? _projectId;
  String? _assignee; // me | none | null (anyone)
  bool _overdue = false;

  /// Current filters sent to GET /api/tickets
  Map<String, dynamic> get _filters => {
        ...widget.baseFilters,
        'q': _q,
        if (_statuses.isNotEmpty) 'status': _statuses.join(','),
        if (_priorities.isNotEmpty) 'priority': _priorities.join(','),
        if (_projectId != null) 'projectId': _projectId,
        if (_assignee != null) 'assigneeId': _assignee,
        if (_overdue) 'overdue': 'true',
      };

  /// Changes when filters change, so the list / board cubits are recreated.
  String get _filterKey => _filters.toString();

  int get _activeCount =>
      (_statuses.isNotEmpty ? 1 : 0) + (_priorities.isNotEmpty ? 1 : 0) + (_projectId != null ? 1 : 0) + (_assignee != null ? 1 : 0) + (_overdue ? 1 : 0);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _statuses = {};
        _priorities = {};
        _projectId = null;
        _assignee = null;
        _overdue = false;
        _q = '';
        _search.clear();
      });

  @override
  Widget build(BuildContext context) {
    final projectFixed = widget.baseFilters.containsKey('projectId');
    return Column(children: [
      _toolbar(projectFixed),
      const Divider(height: 1),
      Expanded(
        child: _board
            ? BlocProvider(
                key: ValueKey('board$_filterKey'),
                create: (_) => BoardCubit(_filters)..load(),
                child: BoardView(showProject: !projectFixed, projectId: widget.baseFilters['projectId'] as String?),
              )
            : BlocProvider(
                key: ValueKey('list$_filterKey'),
                create: (_) => TicketListCubit(_filters)..load(),
                child: _TicketList(onCreate: () => openTicketForm(context, projectId: widget.baseFilters['projectId'] as String?)),
              ),
      ),
    ]);
  }

  Widget _toolbar(bool projectFixed) {
    final c = context.colors;
    final projects = context.watch<DataCubit<List<Project>>>().state.data ?? const [];
    final assigneeFixed = widget.baseFilters.containsKey('assigneeId');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search tickets',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() {
                          _q = '';
                          _search.clear();
                        })),
              ),
              onSubmitted: (v) => setState(() => _q = v.trim()),
            ),
          ),
          const SizedBox(width: 8),
          // List / Board switch
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.view_list_outlined, size: 18), tooltip: 'List'),
              ButtonSegment(value: true, icon: Icon(Icons.view_kanban_outlined, size: 18), tooltip: 'Board'),
            ],
            selected: {_board},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _board = s.first),
          ),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip('Status', _statuses.isEmpty ? null : _statuses.map((s) => metaOf(statusMeta, s).label).join(', '), () async {
              final v = await _multiPick('Status', {for (final s in boardColumns) s: metaOf(statusMeta, s).label}, _statuses);
              if (v != null) setState(() => _statuses = v);
            }),
            _filterChip('Priority', _priorities.isEmpty ? null : _priorities.map((s) => metaOf(priorityMeta, s).label).join(', '), () async {
              final v = await _multiPick('Priority', priorityMeta.map((k, m) => MapEntry(k, m.label)), _priorities);
              if (v != null) setState(() => _priorities = v);
            }),
            if (!projectFixed && widget.showProjectFilter)
              _filterChip('Project', projects.where((p) => p.id == _projectId).firstOrNull?.key, () async {
                final v = await _singlePick('Project', {'': 'All projects', for (final p in projects) p.id: '${p.key} · ${p.name}'}, _projectId ?? '');
                if (v != null) setState(() => _projectId = v.isEmpty ? null : v);
              }),
            if (!assigneeFixed)
              _filterChip('Assignee', {'me': 'Me', 'none': 'Unassigned'}[_assignee], () async {
                final v = await _singlePick('Assignee', {'': 'Anyone', 'me': 'Assigned to me', 'none': 'Unassigned'}, _assignee ?? '');
                if (v != null) setState(() => _assignee = v.isEmpty ? null : v);
              }),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: const Text('Overdue'),
                selected: _overdue,
                showCheckmark: false,
                avatar: Icon(Icons.schedule, size: 15, color: _overdue ? c.danger : c.mutedFg),
                onSelected: (v) => setState(() => _overdue = v),
              ),
            ),
            if (_activeCount > 0 || _q.isNotEmpty)
              TextButton.icon(onPressed: _clear, icon: const Icon(Icons.close, size: 16), label: const Text('Clear filters')),
          ]),
        ),
      ]),
    );
  }

  /// Dropdown-like chip: "Status: In Progress, New ▾"
  Widget _filterChip(String label, String? value, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ActionChip(
          onPressed: onTap,
          backgroundColor: value != null ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(value == null ? label : '$label: $value', overflow: TextOverflow.ellipsis),
            const Icon(Icons.arrow_drop_down, size: 18),
          ]),
        ),
      );

  Future<Set<String>?> _multiPick(String title, Map<String, String> options, Set<String> selected) {
    final picked = {...selected};
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                TextButton(onPressed: () => Navigator.pop(ctx, <String>{}), child: const Text('Clear')),
                FilledButton(onPressed: () => Navigator.pop(ctx, picked), child: const Text('Apply')),
              ]),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final e in options.entries)
                  CheckboxListTile(
                    value: picked.contains(e.key),
                    title: Text(e.value),
                    onChanged: (on) => setLocal(() => on == true ? picked.add(e.key) : picked.remove(e.key)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<String?> _singlePick(String title, Map<String, String> options, String selected) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final e in options.entries)
                  ListTile(
                    title: Text(e.value),
                    trailing: e.key == selected ? const Icon(Icons.check, size: 18) : null,
                    onTap: () => Navigator.pop(ctx, e.key),
                  ),
              ]),
            ),
          ]),
        ),
      );
}

/// Infinite-scroll list of tickets (needs a [TicketListCubit]).
class _TicketList extends StatelessWidget {
  final Future<bool?> Function() onCreate;
  const _TicketList({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return BlocBuilder<TicketListCubit, TicketListState>(
      builder: (context, s) {
        final cubit = context.read<TicketListCubit>();
        if (s.loading && s.items.isEmpty) return const LoadingView();
        if (s.error != null && s.items.isEmpty) return ErrorView(s.error!, onRetry: cubit.load);
        if (s.items.isEmpty) {
          return EmptyView(
            icon: Icons.confirmation_number_outlined,
            title: 'No tickets match',
            message: 'Try changing the filters, or create a new ticket.',
            action: FilledButton.icon(
              onPressed: () async {
                if (await onCreate() == true) cubit.load();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New ticket'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: cubit.load,
          child: NotificationListener<ScrollNotification>(
            // Load the next page when close to the bottom
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) cubit.loadMore();
              return false;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: s.items.length + 2,
              separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Container(
                    color: c.muted,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text('${s.total} ticket${s.total == 1 ? '' : 's'}', style: TextStyle(fontWeight: FontWeight.w600, color: c.mutedFg, fontSize: 13)),
                  );
                }
                if (i == s.items.length + 1) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: s.hasMore ? const LoadingView() : const SizedBox(height: 40),
                  );
                }
                final t = s.items[i - 1];
                return TicketTile(
                  ticket: t,
                  onTap: () async {
                    await openTicket(context, t.key);
                    cubit.load(); // the ticket may have changed
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
