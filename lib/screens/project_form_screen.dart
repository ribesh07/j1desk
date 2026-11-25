import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/api_client.dart';
import '../core/format.dart';
import '../core/meta.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Create a project, or edit it when [existing] is given. Returns true when saved.
Future<bool?> openProjectForm(BuildContext context, {Project? existing}) => Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => ProjectFormScreen(existing: existing)),
    );

class ProjectFormScreen extends StatefulWidget {
  final Project? existing;
  const ProjectFormScreen({super.key, this.existing});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _key = TextEditingController(text: widget.existing?.key);
  late final _description = TextEditingController(text: widget.existing?.description);
  late String _status = widget.existing?.status ?? 'PLANNING';
  late String _priority = widget.existing?.priority ?? 'MEDIUM';
  late String? _teamId = widget.existing?.team?.id;
  late DateTime? _start = widget.existing?.startDate;
  late DateTime? _due = widget.existing?.dueDate;
  late final Set<String> _memberIds = {...?widget.existing?.members.map((m) => m.id)};

  List<Team> _teams = [];
  List<User> _users = [];
  bool _loading = true, _saving = false;
  Map<String, List<String>> _errors = {};

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    Future.wait([Api.teams(), Api.users()]).then((r) {
      if (!mounted) return;
      setState(() {
        _teams = r[0] as List<Team>;
        _users = (r[1] as List<User>).where((u) => u.isActive).toList();
        _loading = false;
      });
    }).catchError((Object e) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'teamId': _teamId,
      'status': _status,
      'priority': _priority,
      'startDate': _start == null ? null : apiDate(_start!),
      'dueDate': _due == null ? null : apiDate(_due!),
      'memberIds': _memberIds.toList(),
    };
    try {
      if (_isEdit) {
        await Api.updateProject(widget.existing!.id, body);
      } else {
        await Api.createProject({...body, 'key': _key.text.trim().toUpperCase()});
      }
      if (!mounted) return;
      showMessage(context, _isEdit ? 'Project updated' : 'Project created');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = e.errors;
      });
      showMessage(context, e.details, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Project settings' : 'New project'),
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
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _label('Project name'),
                      TextFormField(
                        controller: _name,
                        decoration: InputDecoration(hintText: 'e.g. Finance ERP', errorText: _errors['name']?.first),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Project name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      _label('Key'),
                      TextFormField(
                        controller: _key,
                        enabled: !_isEdit, // ticket IDs depend on it
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'ERP',
                          helperText: _isEdit ? 'The key cannot be changed' : 'Tickets will be numbered KEY-001, KEY-002…',
                          errorText: _errors['key']?.first,
                        ),
                        validator: (v) => _isEdit || RegExp(r'^[A-Za-z][A-Za-z0-9]{1,9}$').hasMatch(v?.trim() ?? '')
                            ? null
                            : '2–10 letters/digits, starting with a letter',
                      ),
                      const SizedBox(height: 16),
                      _label('Description'),
                      TextFormField(controller: _description, minLines: 3, maxLines: 8),
                      const SizedBox(height: 16),
                      _label('Team'),
                      DropdownButtonFormField<String?>(
                        initialValue: _teamId,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No team')),
                          for (final t in _teams) DropdownMenuItem(value: t.id, child: Text(t.name)),
                        ],
                        onChanged: (v) => setState(() => _teamId = v),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _dropdown('Status', _status, projectStatusMeta, (v) => setState(() => _status = v))),
                        const SizedBox(width: 12),
                        Expanded(child: _dropdown('Priority', _priority, priorityMeta, (v) => setState(() => _priority = v))),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _dateField('Start date', _start, (d) => setState(() => _start = d))),
                        const SizedBox(width: 12),
                        Expanded(child: _dateField('Due date', _due, (d) => setState(() => _due = d), error: _errors['dueDate']?.first)),
                      ]),
                      const SizedBox(height: 16),
                      _label('Members'),
                      Text('Team members always have access; add other people here.', style: TextStyle(fontSize: 12, color: c.mutedFg)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final u in _users)
                          FilterChip(
                            avatar: UserAvatar(u, size: 20),
                            label: Text(u.name),
                            selected: _memberIds.contains(u.id),
                            showCheckmark: false,
                            onSelected: (on) => setState(() => on ? _memberIds.add(u.id) : _memberIds.remove(u.id)),
                          ),
                      ]),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _label(String text) =>
      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)));

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

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> onChanged, {String? error}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(label),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, initialDate: value ?? now, firstDate: DateTime(now.year - 3), lastDate: DateTime(now.year + 6));
            if (d != null) onChanged(d);
          },
          onLongPress: () => onChanged(null),
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text(value == null ? 'Not set' : formatDate(value)),
        ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(error, style: TextStyle(color: context.colors.danger, fontSize: 12))),
      ]);
}
