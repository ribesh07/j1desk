import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../cubits/nav_cubit.dart';
import '../widgets/common.dart';
import 'ticket_detail_screen.dart';

/// Global search (tickets, projects, people) — the mobile version of the web command palette.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Timer? _debounce;
  Map<String, dynamic>? _results;
  bool _loading = false;
  String _q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Waits 300 ms after typing stops, then searches.
  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(v.trim()));
  }

  Future<void> _search(String q) async {
    setState(() {
      _q = q;
      _loading = q.isNotEmpty;
    });
    if (q.isEmpty) return setState(() => _results = null);
    try {
      final r = await Api.search(q);
      if (mounted && q == _q) setState(() => _results = r);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted && q == _q) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tickets = (_results?['tickets'] as List?) ?? const [];
    final projects = (_results?['projects'] as List?) ?? const [];
    final people = (_results?['users'] as List?) ?? const [];

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.mutedFg)),
        );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search tickets, projects, people', filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
          onChanged: _onChanged,
          onSubmitted: (v) => _search(v.trim()),
        ),
        bottom: _loading ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: _results == null
          ? EmptyView(icon: Icons.search, title: 'Search', message: 'Type a ticket ID (ERP-001), words from a title, a project or a name.')
          : (tickets.isEmpty && projects.isEmpty && people.isEmpty)
              ? EmptyView(icon: Icons.search_off, title: 'No results for “$_q”')
              : ListView(children: [
                  if (tickets.isNotEmpty) header('TICKETS'),
                  for (final t in tickets)
                    ListTile(
                      leading: StatusIcon(t['status'] as String),
                      title: Text(t['title'] as String, overflow: TextOverflow.ellipsis),
                      subtitle: Text(t['key'] as String),
                      onTap: () => openTicket(context, t['key'] as String),
                    ),
                  if (projects.isNotEmpty) header('PROJECTS'),
                  for (final p in projects)
                    ListTile(
                      leading: KeyBadge(p['key'] as String),
                      title: Text(p['name'] as String),
                      onTap: () {
                        context.read<NavCubit>().openProject(p['key'] as String);
                        Navigator.pop(context);
                      },
                    ),
                  if (people.isNotEmpty) header('PEOPLE'),
                  for (final u in people)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(u['name'] as String),
                      subtitle: Text('@${u['username']}'),
                    ),
                ]),
    );
  }
}
