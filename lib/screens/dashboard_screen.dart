import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/data_cubit.dart';
import '../cubits/nav_cubit.dart';
import '../models/models.dart';
import '../widgets/activity_tile.dart';
import '../widgets/common.dart';
import '../widgets/ticket_card.dart';
import 'ticket_detail_screen.dart';

/// "Overview": counters, my upcoming work, overdue tickets, projects, workload and activity.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DataCubit<DashboardData>(Api.dashboard)..load(),
      child: BlocBuilder<DataCubit<DashboardData>, DataState<DashboardData>>(
        builder: (context, s) {
          final cubit = context.read<DataCubit<DashboardData>>();
          if (s.data == null && s.loading) return const LoadingView();
          if (s.data == null) return ErrorView(s.error ?? 'Could not load the dashboard', onRetry: cubit.load);
          return RefreshIndicator(onRefresh: cubit.load, child: _Body(s.data!));
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final DashboardData d;
  const _Body(this.d);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().user;
    final wide = isWide(context);
    final cards = d.cards;

    final left = <Widget>[
      _TicketBox(title: 'My upcoming work', tickets: d.myUpcoming, empty: 'Nothing assigned to you. Enjoy!'),
      const SizedBox(height: 16),
      _TicketBox(title: 'Overdue', tickets: d.overdue, empty: 'No overdue tickets'),
      const SizedBox(height: 16),
      _StatusChart(d.byStatus),
    ];
    final right = <Widget>[
      _projects(context),
      if (d.workload != null) ...[const SizedBox(height: 16), _workload(context)],
      const SizedBox(height: 16),
      Box(
        title: 'Recent activity',
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: d.recentActivity.isEmpty
            ? const Padding(padding: EdgeInsets.all(12), child: Text('No activity yet'))
            : Column(children: [
                for (final a in d.recentActivity.take(12))
                  ActivityTile(a, showTicket: true, onTap: a.ticket == null ? null : () => openTicket(context, a.ticket!.key)),
              ]),
      ),
    ];

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Good to see you, ${user.name.split(' ').first}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text("Here's what's happening across your projects.", style: TextStyle(color: context.colors.mutedFg)),
      const SizedBox(height: 16),
      // Counter cards
      LayoutBuilder(builder: (context, box) {
        final perRow = box.maxWidth >= 1000 ? 4 : 2;
        final w = (box.maxWidth - (perRow - 1) * 10) / perRow;
        Widget card(String label, int? value, IconData icon, Tone tone, VoidCallback? onTap) =>
            SizedBox(width: w, child: _StatCard(label: label, value: value ?? 0, icon: icon, tone: tone, onTap: onTap));
        final nav = context.read<NavCubit>();
        return Wrap(spacing: 10, runSpacing: 10, children: [
          card('Assigned to me', cards['mine'], Icons.account_circle_outlined, Tone.blue, () => nav.open(Section.myTasks)),
          card('In progress', cards['inProgress'], Icons.timelapse, Tone.yellow, () => nav.open(Section.tickets)),
          card('In review', cards['inReview'], Icons.visibility_outlined, Tone.purple, () => nav.open(Section.tickets)),
          card('Overdue', cards['overdue'], Icons.schedule, Tone.red, () => nav.open(Section.tickets)),
          card('New', cards['new'], Icons.fiber_new_outlined, Tone.blue, null),
          card('Waiting', (cards['pending'] ?? 0) + (cards['onHold'] ?? 0), Icons.pause_circle_outline, Tone.orange, null),
          card('Completed', cards['completed'], Icons.check_circle_outline, Tone.green, null),
          card('Total tickets', cards['total'], Icons.confirmation_number_outlined, Tone.gray, null),
        ]);
      }),
      const SizedBox(height: 16),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
        ])
      else ...[
        ...left,
        const SizedBox(height: 16),
        ...right,
      ],
    ]);
  }

  Widget _projects(BuildContext context) {
    final c = context.colors;
    return Box(
      title: 'Projects',
      padding: EdgeInsets.zero,
      child: Column(children: [
        if (d.projects.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No projects')),
        for (final p in d.projects)
          InkWell(
            onTap: () => context.read<NavCubit>().openProject(p.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  KeyBadge(p.key),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  Text('${p.completed}/${p.total}', style: TextStyle(fontSize: 12, color: c.mutedFg)),
                ]),
                const SizedBox(height: 6),
                ProgressLine(p.progress),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _workload(BuildContext context) {
    final c = context.colors;
    return Box(
      title: 'Team workload',
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (final w in d.workload!)
          ListTile(
            leading: UserAvatar(w.user, size: 28),
            title: Text(w.user.name),
            subtitle: Text('${w.open} open · ${w.inProgress} in progress'),
            trailing: w.overdue > 0
                ? ToneBadge(text: '${w.overdue} overdue', tone: Tone.red)
                : Text('On track', style: TextStyle(fontSize: 12, color: c.success)),
          ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Tone tone;
  final VoidCallback? onTap;

  const _StatCard({required this.label, required this.value, required this.icon, required this.tone, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.colors.tone(tone);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.border)),
              child: Icon(icon, size: 18, color: t.fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                Text(label, style: TextStyle(fontSize: 12, color: context.colors.mutedFg), overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TicketBox extends StatelessWidget {
  final String title, empty;
  final List<Ticket> tickets;
  const _TicketBox({required this.title, required this.tickets, required this.empty});

  @override
  Widget build(BuildContext context) => Box(
        title: '$title (${tickets.length})',
        padding: EdgeInsets.zero,
        child: tickets.isEmpty
            ? Padding(padding: const EdgeInsets.all(16), child: Text(empty, style: TextStyle(color: context.colors.mutedFg)))
            : Column(children: [
                for (final (i, t) in tickets.take(8).indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  TicketTile(ticket: t, onTap: () => openTicket(context, t.key)),
                ],
              ]),
      );
}

/// Horizontal bars: number of tickets per status.
class _StatusChart extends StatelessWidget {
  final List<CountItem> items;
  const _StatusChart(this.items);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final data = items.where((i) => i.count > 0).toList();
    final max = data.fold<int>(1, (m, i) => i.count > m ? i.count : m);
    return Box(
      title: 'Tickets by status',
      child: data.isEmpty
          ? Text('No tickets yet', style: TextStyle(color: c.mutedFg))
          : SizedBox(
              height: 220,
              child: BarChart(BarChartData(
                maxY: max * 1.15,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 0.6),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => c.muted,
                    getTooltipItem: (g, _, rod, _) => BarTooltipItem(
                      '${data[g.x].label}\n${rod.toY.toInt()}',
                      TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, meta) => v % 1 == 0 && v <= max
                          ? Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: c.mutedFg))
                          : const SizedBox.shrink(),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          metaOf(statusMeta, data[v.toInt()].key).label.replaceAll(' ', '\n'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9.5, color: c.mutedFg),
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (final (i, item) in data.indexed)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: item.count.toDouble(),
                        width: 14,
                        color: c.tone(metaOf(statusMeta, item.key).tone).fg,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ]),
                ],
              )),
            ),
    );
  }
}
