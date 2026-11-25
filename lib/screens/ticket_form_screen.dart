import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/api_client.dart';
import '../core/format.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

/// Opens the create form (or the edit form when [existing] is given).
/// Returns true when a ticket was saved.
Future<bool?> openTicketForm(BuildContext context, {String? projectId, String? status, TicketDetail? existing}) =>
    Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TicketFormScreen(projectId: projectId, status: status, existing: existing),
    ));

/// New / edit ticket form. Validation mirrors the server (title 3–200 chars, etc.);
/// server field errors (422) are shown under the fields.
class TicketFormScreen extends StatefulWidget {
  final String? projectId;
  final String? status;
  final TicketDetail? existing;

  const TicketFormScreen({super.key, this.projectId, this.status, this.existing});

  @override
  State<TicketFormScreen> createState() => _TicketFormScreenState();
}

class _TicketFormScreenState extends State<TicketFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.ticket.title);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _estimate = TextEditingController(text: _hours(widget.existing?.estimateHours));
  late final _actual = TextEditingController(text: _hours(widget.existing?.actualHours));

  List<Project> _projects = [];
  List<Label> _labels = [];
  String? _projectId;
  late String _type = widget.existing?.ticket.type ?? 'TASK';
  late String _priority = widget.existing?.ticket.priority ?? 'MEDIUM';
  late String _status = widget.status == 'BACKLOG' ? 'BACKLOG' : 'NEW';
  UserSummary? _assignee;
  late UserSummary? _reviewer = widget.existing?.reviewer;
  late final Set<String> _labelIds = {...?widget.existing?.ticket.labels.map((l) => l.id)};
  late DateTime? _due = widget.existing?.ticket.dueDate;

  bool _loading = true;
  bool _saving = false;
  Map<String, List<String>> _errors = {};

  bool get _isEdit => widget.existing != null;

  static String _hours(double? h) => h == null ? '' : (h == h.roundToDouble() ? h.toInt().toString() : h.toString());

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  /// Loads projects (for the picker) and labels.
  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([Api.projects(), Api.labels()]);
      if (!mounted) return;
      setState(() {
        _projects = (results[0] as List<Project>).where((p) => p.archivedAt == null).toList();
        _labels = results[1] as List<Label>;
        // Accept a project id or key from the caller
        final wanted = widget.existing?.ticket.project.id ?? widget.projectId;
        _projectId = _projects.where((p) => p.id == wanted || p.key == wanted).firstOrNull?.id ??
            (_projects.length == 1 ? _projects.first.id : null);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _estimate.dispose();
    _actual.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'type': _type,
      'priority': _priority,
      'reviewerId': _reviewer?.id,
      'labelIds': _labelIds.toList(),
      'dueDate': _due == null ? null : apiDate(_due!),
      'estimateHours': double.tryParse(_estimate.text.trim()),
    };

    try {
      if (_isEdit) {
        body['actualHours'] = double.tryParse(_actual.text.trim());
        await Api.updateTicket(widget.existing!.ticket.key, body);
        if (mounted) showMessage(context, 'Ticket updated');
      } else {
        body['projectId'] = _projectId;
        body['status'] = _status;
        if (_assignee != null) body['assigneeId'] = _assignee!.id;
        final created = await Api.createTicket(body);
        if (mounted) showMessage(context, '${created.ticket.key} created');
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      // 422 → show the field errors under the inputs
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = e.errors;
      });
      showMessage(context, e.details, error: true);
    }
  }

  String? _serverError(String field) => _errors[field]?.first;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit ${widget.existing!.ticket.key}' : 'New ticket'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving || _loading ? null : _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              child: Text(_saving ? 'Saving…' : (_isEdit ? 'Save' : 'Create')),
            ),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (!_isEdit) ...[
                          _label('Project', required: true),
                          DropdownButtonFormField<String>(
                            initialValue: _projectId,
                            isExpanded: true,
                            hint: const Text('Select a project'),
                            items: [
                              for (final p in _projects) DropdownMenuItem(value: p.id, child: Text('${p.key} · ${p.name}', overflow: TextOverflow.ellipsis)),
                            ],
                            validator: (v) => v == null ? 'Select a project' : null,
                            onChanged: (v) => setState(() {
                              _projectId = v;
                              _assignee = null; // people depend on the project
                              _reviewer = null;
                            }),
                            decoration: InputDecoration(errorText: _serverError('projectId')),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _label('Title', required: true),
                        TextFormField(
                          controller: _title,
                          maxLength: 200,
                          decoration: InputDecoration(hintText: 'Short summary of the work', counterText: '', errorText: _serverError('title')),
                          validator: (v) => (v == null || v.trim().length < 3) ? 'Title must be at least 3 characters' : null,
                        ),
                        const SizedBox(height: 16),
                        _label('Description'),
                        TextFormField(
                          controller: _description,
                          minLines: 5,
                          maxLines: 14,
                          decoration: const InputDecoration(hintText: 'Steps, expected result, links… (Markdown supported on the web)'),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: _dropdown('Type', _type, typeMeta, (v) => setState(() => _type = v))),
                          const SizedBox(width: 12),
                          Expanded(child: _dropdown('Priority', _priority, priorityMeta, (v) => setState(() => _priority = v))),
                        ]),
                        const SizedBox(height: 16),
                        if (!_isEdit) ...[
                          _label('Start in'),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'NEW', label: Text('New')),
                              ButtonSegment(value: 'BACKLOG', label: Text('Backlog')),
                            ],
                            selected: {_status},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => setState(() => _status = s.first),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Choosing an assignee moves the ticket to Assigned automatically.', style: TextStyle(fontSize: 12, color: c.mutedFg)),
                          ),
                          const SizedBox(height: 16),
                          _personField('Assignee', _assignee, (u) => setState(() => _assignee = u), error: _serverError('assigneeId')),
                          const SizedBox(height: 16),
                        ],
                        _personField('Reviewer', _reviewer, (u) => setState(() => _reviewer = u), error: _serverError('reviewerId')),
                        const SizedBox(height: 16),
                        _label('Labels'),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final l in _labels)
                            FilterChip(
                              label: Text(l.name),
                              selected: _labelIds.contains(l.id),
                              avatar: CircleAvatar(backgroundColor: hexColor(l.color), radius: 6),
                              showCheckmark: false,
                              onSelected: (on) => setState(() => on ? _labelIds.add(l.id) : _labelIds.remove(l.id)),
                            ),
                        ]),
                        const SizedBox(height: 16),
                        _label('Due date'),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                              onPressed: () async {
                                final now = DateTime.now();
                                final d = await showDatePicker(
                                    context: context, initialDate: _due ?? now, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 5));
                                if (d != null) setState(() => _due = d);
                              },
                              icon: const Icon(Icons.event_outlined, size: 18),
                              label: Text(_due == null ? 'No due date' : formatDate(_due)),
                            ),
                          ),
                          if (_due != null) IconButton(tooltip: 'Clear', icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _due = null)),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: _hoursField('Estimate (hours)', _estimate, 'estimateHours')),
                          if (_isEdit) ...[const SizedBox(width: 12), Expanded(child: _hoursField('Actual (hours)', _actual, 'actualHours'))],
                        ]),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (required) TextSpan(text: ' *', style: TextStyle(color: context.colors.danger)),
        ])),
      );

  Widget _dropdown(String label, String value, Map<String, Meta> options, ValueChanged<String> onChanged) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value.label))],
          onChanged: (v) => onChanged(v!),
        ),
      ]);

  Widget _hoursField(String label, TextEditingController ctrl, String field) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(label),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: 'e.g. 4', errorText: _serverError(field)),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final n = double.tryParse(v.trim());
            return (n == null || n < 0) ? 'Enter a positive number' : null;
          },
        ),
      ]);

  /// Button that opens the people picker for the selected project.
  Widget _personField(String label, UserSummary? value, ValueChanged<UserSummary?> onChanged, {String? error}) {
    final projectId = _isEdit ? widget.existing!.ticket.project.id : _projectId;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(label),
      OutlinedButton(
        style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
        onPressed: projectId == null
            ? () => showMessage(context, 'Select a project first', error: true)
            : () async {
                final pick = await pickUser(context, projectId: projectId, title: label, selectedId: value?.id);
                if (pick != null) onChanged(pick.user);
              },
        child: UserLine(value, emptyText: label == 'Reviewer' ? 'No reviewer' : 'Unassigned'),
      ),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(error, style: TextStyle(color: context.colors.danger, fontSize: 12))),
    ]);
  }
}
