import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/api_client.dart';
import '../core/meta.dart';
import '../core/push_service.dart';
import '../core/theme.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/theme_cubit.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

/// Profile, appearance (dark default / light / system), push notifications, password and sign out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = context.watch<AuthCubit>().user;
    final mode = context.watch<ThemeCubit>().state;
    final push = PushService.instance;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Box(
              title: 'Profile',
              child: Row(children: [
                UserAvatar(user, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text('@${user.username} · ${user.email}', style: TextStyle(color: c.mutedFg)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, children: [
                      ToneBadge(text: roleLabels[user.role] ?? user.role, tone: Tone.blue),
                      if (user.title != null) ToneBadge(text: user.title!, tone: Tone.gray),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Box(
              title: 'Appearance',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Choose how J1Desk looks on this device.', style: TextStyle(color: c.mutedFg)),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 18), label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 18), label: Text('Light')),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined, size: 18), label: Text('System')),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => context.read<ThemeCubit>().set(s.first),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Box(
              title: 'Push notifications',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(push.isReady ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                      color: push.isReady ? c.success : c.mutedFg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(push.isReady
                        ? 'Enabled. You get a notification when tickets you are involved in (or your team\'s tickets) change status, are assigned, commented on or due.'
                        : push.isConfigured
                            ? 'Firebase could not start on this device.'
                            : 'Not configured. Add the Firebase values to the .env file and rebuild the app.'),
                  ),
                ]),
                if (push.isReady) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await push.registerDevice();
                      if (context.mounted) showMessage(context, 'This device is registered for notifications');
                    },
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Re-register this device'),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            const _PasswordBox(),
            const SizedBox(height: 16),
            Box(
              title: 'About',
              child: Column(children: [
                PropRow('Server', SelectableText(ApiClient.instance.baseUrl)),
                PropRow('API docs', SelectableText('${ApiClient.instance.baseUrl}/api/docs')),
              ]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: c.danger),
              onPressed: () async {
                if (await confirm(context, title: 'Sign out?', confirmLabel: 'Sign out', danger: true) && context.mounted) {
                  context.read<AuthCubit>().logout();
                }
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    ]);
  }
}

class _PasswordBox extends StatefulWidget {
  const _PasswordBox();

  @override
  State<_PasswordBox> createState() => _PasswordBoxState();
}

class _PasswordBoxState extends State<_PasswordBox> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false, _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.changePassword(_current.text, _next.text);
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      showMessage(context, 'Password changed');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.details, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          suffixIcon: IconButton(
            tooltip: _show ? 'Hide password' : 'Show password',
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
            onPressed: () => setState(() => _show = !_show),
          ),
        );
    return Box(
      title: 'Change password',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _current,
            obscureText: !_show,
            decoration: deco('Current password'),
            validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _next,
            obscureText: !_show,
            decoration: deco('New password'),
            validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _confirm,
            obscureText: !_show,
            decoration: deco('Confirm new password'),
            validator: (v) => v != _next.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Update password')),
          ),
        ]),
      ),
    );
  }
}
