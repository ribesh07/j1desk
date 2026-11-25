import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/data_cubit.dart';
import '../cubits/nav_cubit.dart';
import '../cubits/unread_cubit.dart';
import '../models/models.dart';
import 'common.dart';
import 'logo.dart';

/// Drawer items, same order as the web sidebar (src/components/layout/nav-items.ts).
const navItems = <(Section, String, IconData)>[
  (Section.overview, 'Overview', Icons.dashboard_outlined),
  (Section.myTasks, 'My Tasks', Icons.account_circle_outlined),
  (Section.inbox, 'Inbox', Icons.inbox_outlined),
  (Section.projects, 'Projects', Icons.view_kanban_outlined),
  (Section.tickets, 'All Tickets', Icons.confirmation_number_outlined),
  (Section.team, 'Team', Icons.groups_outlined),
  (Section.reports, 'Reports', Icons.bar_chart_outlined),
  (Section.settings, 'Settings', Icons.settings_outlined),
];

/// Left sidebar: team switcher, navigation, projects and the signed-in user.
///
/// Phones use it inside a slide-out [Drawer]; tablets show it permanently and it can be
/// collapsed to icons only ([collapsed]), like the web app's sidebar.
class AppSidebar extends StatelessWidget {
  final bool collapsed;
  final bool inDrawer;
  const AppSidebar({super.key, this.collapsed = false, this.inDrawer = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.watch<NavCubit>().state;
    final user = context.watch<AuthCubit>().state.user!;
    final unread = context.watch<UnreadCubit>().state;
    final projects = context.watch<DataCubit<List<Project>>>().state.data ?? const [];
    final teams = context.watch<DataCubit<List<Team>>>().state.data ?? const [];
    final team = teams.where((t) => t.id == nav.teamId).firstOrNull;
    final visibleProjects = team == null ? projects : projects.where((p) => p.team?.id == team.id).toList();

    // Navigate, then close the drawer on phones.
    void go(VoidCallback action) {
      action();
      if (inDrawer) Navigator.of(context).pop();
    }

    return Container(
      color: c.sidebar,
      child: SafeArea(
        right: false,
        child: Column(children: [
          // ── Workspace / team selector ──
          SizedBox(
            height: 56,
            child: PopupMenuButton<String?>(
              tooltip: 'Filter projects by team',
              position: PopupMenuPosition.under,
              onSelected: (id) => context.read<NavCubit>().setTeam(id),
              itemBuilder: (_) => [
                const PopupMenuItem(enabled: false, child: Text('Filter projects by team', style: TextStyle(fontSize: 12))),
                CheckedPopupMenuItem(value: null, checked: team == null, child: const Text('All teams')),
                for (final t in teams) CheckedPopupMenuItem(value: t.id, checked: team?.id == t.id, child: Text(t.name)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                  const AppLogo(size: 28),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('J1Desk', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        Text(team?.name ?? 'All teams', style: TextStyle(fontSize: 12, color: c.mutedFg)),
                      ]),
                    ),
                    Icon(Icons.unfold_more, size: 18, color: c.mutedFg),
                  ],
                ]),
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Navigation + projects ──
          Expanded(
            child: ListView(padding: const EdgeInsets.all(8), children: [
              for (final (section, label, icon) in navItems)
                if (section != Section.reports || user.permissions.viewReports)
                  _NavTile(
                    icon: icon,
                    label: label,
                    active: nav.section == section && (section != Section.projects || nav.projectKey == null),
                    collapsed: collapsed,
                    badge: section == Section.inbox ? unread : 0,
                    onTap: () => go(() => context.read<NavCubit>().open(section)),
                  ),
              if (!collapsed) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 4, 4),
                  child: Text('Projects', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.mutedFg)),
                ),
                if (visibleProjects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('No projects', style: TextStyle(fontSize: 12, color: c.mutedFg)),
                  ),
                for (final p in visibleProjects)
                  _NavTile(
                    leading: KeyBadge(p.key),
                    label: p.name,
                    active: nav.projectKey == p.key,
                    collapsed: false,
                    onTap: () => go(() => context.read<NavCubit>().openProject(p.key)),
                  ),
              ],
            ]),
          ),

          // ── Signed-in user + collapse toggle ──
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: collapsed
                ? Column(children: [
                    UserAvatar(user, size: 28),
                    IconButton(
                      tooltip: 'Expand sidebar',
                      icon: const Icon(Icons.keyboard_double_arrow_right, size: 20),
                      onPressed: () => context.read<NavCubit>().toggleCollapsed(),
                    ),
                  ])
                : Row(children: [
                    UserAvatar(user, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        Text('@${user.username}', style: TextStyle(fontSize: 12, color: c.mutedFg), overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    if (!inDrawer)
                      IconButton(
                        tooltip: 'Collapse sidebar',
                        icon: const Icon(Icons.keyboard_double_arrow_left, size: 20),
                        onPressed: () => context.read<NavCubit>().toggleCollapsed(),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

/// One row of the sidebar. Active rows get the blue bar on the left (GitHub style).
class _NavTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String label;
  final bool active, collapsed;
  final int badge;
  final VoidCallback onTap;

  const _NavTile({this.icon, this.leading, required this.label, required this.active, required this.collapsed, this.badge = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = Theme.of(context).colorScheme.onSurface;
    final tile = Material(
      color: active ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Stack(fit: StackFit.expand, children: [
            if (active)
              Positioned(
                left: 0,
                top: 8,
                bottom: 8,
                child: Container(width: 3, decoration: BoxDecoration(color: c.link, borderRadius: BorderRadius.circular(2))),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                leading ?? Icon(icon, size: 18, color: active ? fg : c.mutedFg),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: fg.withValues(alpha: active ? 1 : 0.85))),
                  ),
                ],
                if (badge > 0 && !collapsed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF1F6FEB), borderRadius: BorderRadius.circular(10)),
                    child: Text(badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                if (badge > 0 && collapsed)
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF1F6FEB), shape: BoxShape.circle)),
              ]),
            ),
          ]),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: collapsed ? Tooltip(message: label, child: tile) : tile,
    );
  }
}
