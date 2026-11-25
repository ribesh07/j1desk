import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

/// Asks for a reason (reject, put on hold, request changes, reopen …). Returns null when cancelled.
Future<String?> askReason(BuildContext context, {required String title, String? description, String confirmLabel = 'Submit'}) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      content: Form(
        key: formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (description != null) ...[
            Text(description, style: TextStyle(color: ctx.colors.mutedFg)),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'Reason'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'A reason is required' : null,
          ),
        ]),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text.trim());
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Yes / no confirmation. Returns true when confirmed.
Future<bool> confirm(BuildContext context, {required String title, String? message, String confirmLabel = 'Confirm', bool danger = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      content: message == null ? null : Text(message),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: ctx.colors.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Result of [pickUser]: `cleared` means "Unassigned" was chosen.
class UserPick {
  final User? user;
  final bool cleared;
  const UserPick(this.user, {this.cleared = false});
}

/// Bottom sheet with a searchable list of the project's people.
Future<UserPick?> pickUser(BuildContext context, {required String projectId, String title = 'Assign to', String? selectedId, bool allowNone = true}) {
  return showModalBottomSheet<UserPick>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _UserPickerSheet(projectId: projectId, title: title, selectedId: selectedId, allowNone: allowNone),
  );
}

class _UserPickerSheet extends StatefulWidget {
  final String projectId, title;
  final String? selectedId;
  final bool allowNone;
  const _UserPickerSheet({required this.projectId, required this.title, this.selectedId, required this.allowNone});

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  late final Future<List<User>> _users = Api.users(projectId: widget.projectId);
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Filter people'),
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
            ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<User>>(
            future: _users,
            builder: (context, snap) {
              if (snap.hasError) return ErrorView(snap.error.toString());
              if (!snap.hasData) return const LoadingView();
              final users = snap.data!
                  .where((u) => u.isActive && (u.name.toLowerCase().contains(_q) || u.username.contains(_q)))
                  .toList();
              return ListView(children: [
                if (widget.allowNone)
                  ListTile(
                    leading: const UserAvatar(null, size: 28),
                    title: const Text('Unassigned'),
                    trailing: widget.selectedId == null ? const Icon(Icons.check, size: 18) : null,
                    onTap: () => Navigator.pop(context, const UserPick(null, cleared: true)),
                  ),
                for (final u in users)
                  ListTile(
                    leading: UserAvatar(u, size: 28),
                    title: Text(u.name),
                    subtitle: Text('@${u.username} · ${u.title ?? u.role}'),
                    trailing: u.id == widget.selectedId ? const Icon(Icons.check, size: 18) : null,
                    onTap: () => Navigator.pop(context, UserPick(u)),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

/// Simple single-choice bottom sheet (e.g. priority, type).
Future<String?> pickOption(BuildContext context, {required String title, required Map<String, String> options, String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
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
