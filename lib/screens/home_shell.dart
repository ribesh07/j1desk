import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/push_service.dart';
import '../core/theme.dart';
import '../cubits/data_cubit.dart';
import '../cubits/nav_cubit.dart';
import '../cubits/unread_cubit.dart';
import '../models/models.dart';
import '../widgets/app_drawer.dart';
import 'dashboard_screen.dart';
import 'inbox_screen.dart';
import 'projects_screen.dart';
import 'reports_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'team_screen.dart';
import 'ticket_detail_screen.dart';
import 'ticket_form_screen.dart';
import 'tickets_screen.dart';

/// Main layout after sign-in: app bar + left sidebar + the selected section.
///
/// Phones (< 900 px): the sidebar is a slide-out drawer (hamburger / swipe from the left).
/// Tablets: the sidebar is always visible and can be collapsed to icons, like the web app.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final unread = context.read<UnreadCubit>();
    unread.refresh();
    // Refresh the unread badge every minute, and immediately when a push arrives.
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => unread.refresh());
    PushService.instance.onMessage = unread.refresh;
    // Tapping a push notification opens the ticket
    PushService.instance.onOpenTicket = (key) {
      if (mounted) openTicket(context, key);
    };
    PushService.instance.handleLaunchMessage();
  }

  @override
  void dispose() {
    _poll?.cancel();
    PushService.instance.onOpenTicket = null;
    PushService.instance.onMessage = null;
    super.dispose();
  }

  String _title(NavState nav) =>
      nav.projectKey ?? navItems.firstWhere((i) => i.$1 == nav.section).$2;

  Widget _body(NavState nav) => switch (nav.section) {
        Section.overview => const DashboardScreen(),
        Section.myTasks => const TicketsView(key: ValueKey('my'), baseFilters: {'assigneeId': 'me'}),
        Section.inbox => const InboxScreen(),
        Section.projects => const ProjectsScreen(),
        Section.tickets => const TicketsView(key: ValueKey('all')),
        Section.team => const TeamScreen(),
        Section.reports => const ReportsScreen(),
        Section.settings => const SettingsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavCubit>().state;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final c = context.colors;

    return PopScope(
      // Android back: close the project, then go to Overview, then leave the app.
      canPop: nav.section == Section.overview && nav.projectKey == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final cubit = context.read<NavCubit>();
        nav.projectKey != null ? cubit.openProject(null) : cubit.open(Section.overview);
      },
      child: Scaffold(
        drawer: wide ? null : const Drawer(width: 290, child: AppSidebar(inDrawer: true)),
        appBar: AppBar(
          title: Text(_title(nav)),
          actions: [
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
            IconButton(
              tooltip: 'New ticket',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => openTicketForm(context, projectId: nav.projectKey),
            ),
            BlocBuilder<UnreadCubit, int>(
              builder: (context, unread) => IconButton(
                tooltip: 'Inbox',
                onPressed: () => context.read<NavCubit>().open(Section.inbox),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  backgroundColor: c.link,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(Icons.notifications_none),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Row(children: [
          if (wide) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: nav.collapsed ? 64 : 256,
              child: AppSidebar(collapsed: nav.collapsed),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: _body(nav)),
        ]),
      ),
    );
  }
}

/// Provides the data shared by the whole signed-in app (projects + teams for the sidebar).
class SignedInScope extends StatelessWidget {
  const SignedInScope({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NavCubit()),
        BlocProvider(create: (_) => DataCubit<List<Project>>(() => Api.projects())..load()),
        BlocProvider(create: (_) => DataCubit<List<Team>>(Api.teams)..load()),
      ],
      child: const HomeShell(),
    );
  }
}
