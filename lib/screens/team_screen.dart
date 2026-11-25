import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../cubits/data_cubit.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Teams and people with their current workload.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DataCubit<List<User>>(() => Api.users())..load(),
      child: const DefaultTabController(
        length: 2,
        child: Column(children: [
          TabBar(tabs: [Tab(text: 'People'), Tab(text: 'Teams')]),
          Expanded(child: TabBarView(children: [_People(), _Teams()])),
        ]),
      ),
    );
  }
}

class _People extends StatefulWidget {
  const _People();

  @override
  State<_People> createState() => _PeopleState();
}

class _PeopleState extends State<_People> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<DataCubit<List<User>>>();
    final s = context.watch<DataCubit<List<User>>>().state;
    if (s.data == null && s.loading) return const LoadingView();
    if (s.data == null) return ErrorView(s.error ?? 'Error', onRetry: cubit.load);
    final users = s.data!.where((u) => u.name.toLowerCase().contains(_q) || u.username.contains(_q)).toList();

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Find a person'),
          onChanged: (v) => setState(() => _q = v.toLowerCase()),
        ),
        const SizedBox(height: 12),
        Box(
          title: '${users.length} people',
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, u) in users.indexed) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  UserAvatar(u, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('@${u.username}', style: TextStyle(color: c.mutedFg, fontSize: 12)),
                        ToneBadge(text: roleLabels[u.role] ?? u.role, tone: u.role == 'ADMIN' ? Tone.purple : (u.role == 'TEAM_LEADER' ? Tone.blue : Tone.gray)),
                        if (!u.isActive) const ToneBadge(text: 'Inactive', tone: Tone.red),
                      ]),
                      if (u.title != null) Text(u.title!, style: TextStyle(fontSize: 12.5, color: c.mutedFg)),
                      if (u.teams.isNotEmpty) Text(u.teams.map((t) => t.name).join(', '), style: TextStyle(fontSize: 12, color: c.mutedFg)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${u.openTickets} open', style: const TextStyle(fontSize: 12.5)),
                    if (u.overdueTickets > 0) Text('${u.overdueTickets} overdue', style: TextStyle(fontSize: 12, color: c.danger)),
                  ]),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Teams extends StatelessWidget {
  const _Teams();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cubit = context.read<DataCubit<List<Team>>>();
    final s = context.watch<DataCubit<List<Team>>>().state;
    if (s.data == null && s.loading) return const LoadingView();
    if (s.data == null) return ErrorView(s.error ?? 'Error', onRetry: cubit.load);
    if (s.data!.isEmpty) return const EmptyView(icon: Icons.groups_outlined, title: 'No teams yet');

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        for (final t in s.data!) ...[
          Box(
            title: t.name,
            trailing: Text('${t.members.length} members · ${t.projectCount} project${t.projectCount == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: c.mutedFg)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (t.description != null) ...[Text(t.description!, style: TextStyle(color: c.mutedFg)), const SizedBox(height: 10)],
              PropRow('Leader', UserLine(t.leader, emptyText: 'No leader')),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in t.members)
                  Chip(avatar: UserAvatar(m, size: 20), label: Text(m.name), visualDensity: VisualDensity.compact),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}
