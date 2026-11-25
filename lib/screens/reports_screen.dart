import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../cubits/data_cubit.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Ticket report for a date range: totals, created vs completed timeline, by priority/project/member.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 29)), end: DateTime.now());
  String? _projectId;
  late final _cubit = DataCubit<TicketReport>(_fetch)..load();

  Future<TicketReport> _fetch() => Api.ticketReport(from: apiDate(_range.start), to: apiDate(_range.end), projectId: _projectId);

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime.now(),
    );
    if (r == null) return;
    setState(() => _range = r);
    _cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<DataCubit<List<Project>>>().state.data ?? const [];
    return BlocBuilder<DataCubit<TicketReport>, DataState<TicketReport>>(
      bloc: _cubit,
      builder: (context, s) {
        return RefreshIndicator(
          onRefresh: _cubit.load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text('${formatDate(_range.start)} – ${formatDate(_range.end)}'),
              ),
              DropdownButton<String?>(
                value: _projectId,
                hint: const Text('All projects'),
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All projects')),
                  for (final p in projects) DropdownMenuItem(value: p.id, child: Text(p.key)),
                ],
                onChanged: (v) {
                  setState(() => _projectId = v);
                  _cubit.load();
                },
              ),
              if (s.loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
            const SizedBox(height: 16),
            if (s.data == null && s.loading) const SizedBox(height: 300, child: LoadingView()),
            if (s.data == null && s.error != null) ErrorView(s.error!, onRetry: _cubit.load),
            if (s.data != null) ..._report(s.data!),
          ]),
        );
      },
    );
  }

  List<Widget> _report(TicketReport r) {
    final c = context.colors;
    final totals = [
      ('Created', r.totals['created'] ?? 0, Tone.blue),
      ('Completed', r.totals['completed'] ?? 0, Tone.green),
      ('Open', r.totals['open'] ?? 0, Tone.yellow),
      ('Overdue', r.totals['overdue'] ?? 0, Tone.red),
    ];
    return [
      LayoutBuilder(builder: (context, box) {
        final perRow = box.maxWidth > 700 ? 4 : 2;
        final w = (box.maxWidth - (perRow - 1) * 10) / perRow;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (label, value, tone) in totals)
            SizedBox(
              width: w,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: c.tone(tone).fg)),
                    Text(label, style: TextStyle(color: c.mutedFg, fontSize: 12)),
                  ]),
                ),
              ),
            ),
        ]);
      }),
      const SizedBox(height: 16),
      Box(title: 'Created vs completed', child: SizedBox(height: 220, child: _timeline(r))),
      const SizedBox(height: 16),
      Box(
        title: 'By priority',
        child: Column(children: [
          for (final p in r.byPriority) _bar(metaOf(priorityMeta, p.key).label, p.count, r.byPriority.fold(0, (a, b) => a + b.count), c.tone(metaOf(priorityMeta, p.key).tone).fg),
        ]),
      ),
      const SizedBox(height: 16),
      Box(
        title: 'By project',
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final p in r.byProject)
            ListTile(
              leading: KeyBadge(p.key),
              title: Text(p.label),
              trailing: Text('${p.completed}/${p.count} done'),
            ),
          if (r.byProject.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('No data', style: TextStyle(color: c.mutedFg))),
        ]),
      ),
      const SizedBox(height: 16),
      Box(
        title: 'By member',
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 48,
            columns: const [
              DataColumn(label: Text('Member')),
              DataColumn(label: Text('Assigned'), numeric: true),
              DataColumn(label: Text('Completed'), numeric: true),
              DataColumn(label: Text('Open'), numeric: true),
              DataColumn(label: Text('Overdue'), numeric: true),
            ],
            rows: [
              for (final m in r.byMember)
                DataRow(cells: [
                  DataCell(UserLine(m.user)),
                  DataCell(Text('${m.assigned}')),
                  DataCell(Text('${m.completed}')),
                  DataCell(Text('${m.open}')),
                  DataCell(Text('${m.overdue}', style: TextStyle(color: m.overdue > 0 ? c.danger : null))),
                ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _bar(String label, int value, int total, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: total == 0 ? 0 : value / total, minHeight: 10, color: color, backgroundColor: context.colors.muted),
            ),
          ),
          SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.right)),
        ]),
      );

  /// Two lines: tickets created (blue) and completed (green) per day.
  Widget _timeline(TicketReport r) {
    final c = context.colors;
    if (r.timeline.isEmpty) return Center(child: Text('No data', style: TextStyle(color: c.mutedFg)));
    final maxY = r.timeline.fold<int>(1, (m, t) => [m, t.created, t.completed].reduce((a, b) => a > b ? a : b)).toDouble();
    LineChartBarData line(List<FlSpot> spots, Color color) => LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 2,
          isCurved: false,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
        );
    final step = (r.timeline.length / 5).ceil().clamp(1, 1000);
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY + 1,
      gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 0.6)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: (maxY / 4).ceilToDouble().clamp(1, 1000),
            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: c.mutedFg)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: step.toDouble(),
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= r.timeline.length) return const SizedBox.shrink();
              final d = DateTime.tryParse(r.timeline[i].date);
              return Text(d == null ? '' : '${d.day}/${d.month}', style: TextStyle(fontSize: 10, color: c.mutedFg));
            },
          ),
        ),
      ),
      lineBarsData: [
        line([for (final (i, t) in r.timeline.indexed) FlSpot(i.toDouble(), t.created.toDouble())], c.link),
        line([for (final (i, t) in r.timeline.indexed) FlSpot(i.toDouble(), t.completed.toDouble())], c.success),
      ],
    ));
  }
}
