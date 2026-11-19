import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _name = TextEditingController();
  final _pass = TextEditingController();
  bool _hidePass = true;

  @override
  void dispose() {
    _name.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _pass.text.isEmpty) return;
    ref.read(authProvider.notifier).login(_name.text.trim(), _pass.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GridColors.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GridColors.line),
          ),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sign in to Grid',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _name,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Username, phone or email',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pass,
                  obscureText: _hidePass,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _hidePass ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _hidePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _hidePass = !_hidePass),
                    ),
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      auth.error ?? '',
                      style: const TextStyle(
                        color: Color(0xFFFF9B9B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: auth.busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(auth.busy ? 'Signing in…' : 'Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
