import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/data_cubit.dart';
import '../cubits/nav_cubit.dart';
import '../models/models.dart';
import '../widgets/activity_tile.dart';
import '../widgets/common.dart';
import 'project_form_screen.dart';
import 'ticket_detail_screen.dart';
import 'tickets_screen.dart';

/// "Projects" section: the list of projects, or one project when [NavState.projectKey] is set.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final key = context.select<NavCubit, String?>((n) => n.state.projectKey);
    return key == null ? const _ProjectList() : ProjectView(key: ValueKey(key), projectKey: key);
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = context.watch<AuthCubit>().user;
    final cubit = context.read<DataCubit<List<Project>>>();
    final state = context.watch<DataCubit<List<Project>>>().state;
    final projects = state.data;

    if (projects == null && state.loading) return const LoadingView();
    if (projects == null) return ErrorView(state.error ?? 'Could not load projects', onRetry: cubit.load);

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: Text('${projects.length} project${projects.length == 1 ? '' : 's'}', style: TextStyle(color: c.mutedFg))),
          if (user.permissions.createProjects)
            FilledButton.icon(
              onPressed: () async {
                if (await openProjectForm(context) == true) cubit.load();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New project'),
            ),
        ]),
        const SizedBox(height: 12),
        if (projects.isEmpty)
          const EmptyView(icon: Icons.view_kanban_outlined, title: 'No projects yet', message: 'Projects you own or belong to appear here.'),
        // Grid of cards on tablets, a list on phones
        LayoutBuilder(builder: (context, box) {
          final perRow = box.maxWidth >= 1100 ? 3 : (box.maxWidth >= 680 ? 2 : 1);
          final width = (box.maxWidth - (perRow - 1) * 12) / perRow;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final p in projects) SizedBox(width: width, child: _ProjectCard(p)),
          ]);
        }),
      ]),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard(this.project);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = project;
    final status = metaOf(projectStatusMeta, p.status);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => context.read<NavCubit>().openProject(p.key),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              KeyBadge(p.key),
              const SizedBox(width: 8),
              Expanded(child: Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, color: c.link, fontSize: 15), overflow: TextOverflow.ellipsis)),
              ToneBadge(text: status.label, tone: status.tone),
            ]),
            const SizedBox(height: 8),
            Text(p.description ?? 'No description', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.mutedFg, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ProgressLine(p.stats.progress)),
              const SizedBox(width: 8),
              Text('${p.stats.progress}%', style: TextStyle(fontSize: 12, color: c.mutedFg)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 4, children: [
              _stat(context, Icons.confirmation_number_outlined, '${p.stats.total} tickets'),
              _stat(context, Icons.check_circle_outline, '${p.stats.completed} done'),
              if (p.stats.overdue > 0) _stat(context, Icons.schedule, '${p.stats.overdue} overdue', color: c.danger),
              if (p.team != null) _stat(context, Icons.groups_outlined, p.team!.name),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              for (final m in p.members.take(6)) Padding(padding: const EdgeInsets.only(right: 3), child: UserAvatar(m, size: 22)),
              if (p.members.length > 6) Text(' +${p.members.length - 6}', style: TextStyle(fontSize: 12, color: c.mutedFg)),
              const Spacer(),
              if (p.dueDate != null) Text('Due ${formatDate(p.dueDate)}', style: TextStyle(fontSize: 12, color: c.mutedFg)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String text, {Color? color}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color ?? context.colors.mutedFg),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color ?? context.colors.mutedFg)),
      ]);
}

/// One project: Board (default) / List / Overview / Activity tabs, like the web project page.
class ProjectView extends StatelessWidget {
  final String projectKey;
  const ProjectView({super.key, required this.projectKey});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DataCubit<Project>(() => Api.project(projectKey))..load(),
      child: BlocBuilder<DataCubit<Project>, DataState<Project>>(
        builder: (context, s) {
          if (s.data == null && s.loading) return const LoadingView();
          if (s.data == null) return ErrorView(s.error ?? 'Project not found', onRetry: () => context.read<DataCubit<Project>>().load());
          final p = s.data!;
          return DefaultTabController(
            length: 4,
            child: Column(children: [
              _header(context, p),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(icon: Icon(Icons.view_kanban_outlined, size: 18), text: 'Board', iconMargin: EdgeInsets.zero, height: 52),
                  Tab(icon: Icon(Icons.view_list_outlined, size: 18), text: 'List', iconMargin: EdgeInsets.zero, height: 52),
                  Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Overview', iconMargin: EdgeInsets.zero, height: 52),
                  Tab(icon: Icon(Icons.history, size: 18), text: 'Activity', iconMargin: EdgeInsets.zero, height: 52),
                ],
              ),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(), // swiping would fight with the board
                  children: [
                    TicketsView(baseFilters: {'projectId': p.id}, startWithBoard: true),
                    TicketsView(baseFilters: {'projectId': p.id}),
                    _Overview(p),
                    _ProjectActivity(p.id),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, Project p) {
    final c = context.colors;
    final status = metaOf(projectStatusMeta, p.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(children: [
        IconButton(
          tooltip: 'All projects',
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.read<NavCubit>().openProject(null),
        ),
        KeyBadge(p.key),
        const SizedBox(width: 8),
        Expanded(child: Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ToneBadge(text: status.label, tone: status.tone),
        if (p.canEdit)
          IconButton(
            tooltip: 'Project settings',
            icon: Icon(Icons.settings_outlined, size: 20, color: c.mutedFg),
            onPressed: () async {
              if (await openProjectForm(context, existing: p) == true && context.mounted) {
                context.read<DataCubit<Project>>().load();
                context.read<DataCubit<List<Project>>>().load();
              }
            },
          ),
      ]),
    );
  }
}

class _Overview extends StatelessWidget {
  final Project p;
  const _Overview(this.p);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = p.stats;
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (p.description != null) ...[Text(p.description!, style: const TextStyle(height: 1.5)), const SizedBox(height: 16)],
      Box(
        title: 'Progress',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: ProgressLine(s.progress)), const SizedBox(width: 8), Text('${s.progress}%')]),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _count(context, 'Total', s.total, Tone.gray),
            _count(context, 'In progress', s.inProgress, Tone.yellow),
            _count(context, 'Waiting', s.pending, Tone.orange),
            _count(context, 'Completed', s.completed, Tone.green),
            _count(context, 'Overdue', s.overdue, Tone.red),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Box(
        title: 'Details',
        child: Column(children: [
          PropRow('Owner', UserLine(p.owner)),
          PropRow('Team', Text(p.team?.name ?? '—')),
          PropRow('Priority', PriorityBadge(p.priority)),
          PropRow('Start date', Text(formatDate(p.startDate))),
          PropRow('Due date', Text(formatDate(p.dueDate))),
        ]),
      ),
      const SizedBox(height: 16),
      Box(
        title: 'Members (${p.members.length})',
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final m in p.members)
            ListTile(leading: UserAvatar(m, size: 28), title: Text(m.name), subtitle: Text('@${m.username}')),
          if (p.members.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('No members', style: TextStyle(color: c.mutedFg))),
        ]),
      ),
    ]);
  }

  Widget _count(BuildContext context, String label, int value, Tone tone) {
    final t = context.colors.tone(tone);
    return Container(
      width: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: t.fg)),
        Text(label, style: TextStyle(fontSize: 12, color: t.fg)),
      ]),
    );
  }
}

class _ProjectActivity extends StatelessWidget {
  final String projectId;
  const _ProjectActivity(this.projectId);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DataCubit<Paged<Activity>>(() => Api.projectActivity(projectId))..load(),
      child: BlocBuilder<DataCubit<Paged<Activity>>, DataState<Paged<Activity>>>(
        builder: (context, s) {
          if (s.data == null && s.loading) return const LoadingView();
          if (s.data == null) return ErrorView(s.error ?? 'Error', onRetry: () => context.read<DataCubit<Paged<Activity>>>().load());
          if (s.data!.items.isEmpty) return const EmptyView(icon: Icons.history, title: 'No activity yet');
          return RefreshIndicator(
            onRefresh: () => context.read<DataCubit<Paged<Activity>>>().load(),
            child: ListView(padding: const EdgeInsets.all(12), children: [
              for (final a in s.data!.items)
                ActivityTile(a, showTicket: true, onTap: a.ticket == null ? null : () => openTicket(context, a.ticket!.key)),
            ]),
          );
        },
      ),
    );
  }
}
