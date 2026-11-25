import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/push_service.dart';
import 'cubits/theme_cubit.dart';

/// Entry point: load `.env`, start Firebase push (if configured), restore the theme, run the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  await PushService.instance.init();
  final theme = ThemeCubit();
  await theme.load(); // dark by default, or the user's saved choice
  runApp(J1DeskApp(themeCubit: theme));
}
