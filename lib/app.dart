import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/domain/auth_state.dart';
import 'features/auth/presentation/auth_notifier.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/live/presentation/live_screen.dart';

class GridApp extends StatelessWidget {
  const GridApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Grid Direct Voice',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const _Shell(),
  );
}

/// The phone-shaped frame, and which screen is inside it.
class _Shell extends ConsumerWidget {
  const _Shell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authProvider.select((s) => s.status));
    final wide = MediaQuery.of(context).size.width > 520;
    final body = switch (status) {
      AuthStatus.loading => const Center(child: CircularProgressIndicator()),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.ready => const LiveScreen(),
      AuthStatus.unreachable => const _Unreachable(),
    };
    final screen = SafeArea(child: body);
    if (!wide) return Scaffold(body: screen);
    return Scaffold(
      backgroundColor: GridColors.page,
      body: Center(
        child: Container(
          width: 390,
          margin: const EdgeInsets.symmetric(vertical: 16),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: GridColors.screen,
            borderRadius: BorderRadius.circular(44),
            border: Border.all(width: 10),
          ),
          child: screen,
        ),
      ),
    );
  }
}

class _Unreachable extends ConsumerWidget {
  const _Unreachable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(authProvider.select((s) => s.error));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not reach Grid',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: GridColors.soft),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(authProvider.notifier).retry(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
