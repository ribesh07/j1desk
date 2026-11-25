import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'cubits/auth_cubit.dart';
import 'cubits/theme_cubit.dart';
import 'cubits/unread_cubit.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'widgets/logo.dart';

/// Root widget: app-wide cubits, light/dark themes, and the sign-in gate.
class J1DeskApp extends StatelessWidget {
  final ThemeCubit themeCubit;
  const J1DeskApp({super.key, required this.themeCubit});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: themeCubit),
        BlocProvider(create: (_) => AuthCubit()..restore()),
        BlocProvider(create: (_) => UnreadCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) => MaterialApp(
          title: 'J1Desk',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          // Light status-bar icons on the dark theme, dark icons on the light theme
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: Theme.of(context).brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            child: child!,
          ),
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

/// Shows splash → login → app depending on the session.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      // Signed out: clear the unread badge and any open pages
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.status == AuthStatus.signedOut) {
          context.read<UnreadCubit>().reset();
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      },
      builder: (context, state) => switch (state.status) {
        AuthStatus.unknown => const Scaffold(body: Center(child: AppLogo(size: 56))),
        AuthStatus.signedOut => const LoginScreen(),
        // A new key per user resets all per-user state after switching accounts
        AuthStatus.signedIn => SignedInScope(key: ValueKey(state.user!.id)),
      },
    );
  }
}
