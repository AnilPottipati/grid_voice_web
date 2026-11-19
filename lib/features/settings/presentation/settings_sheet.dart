import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../live/presentation/live_notifier.dart';
import '../../users/presentation/users_notifier.dart';
import '../../voice/presentation/voiceprint_notifier.dart';
import '../../../core/wake/wake_word.dart';
import '../domain/server_config.dart';
import 'settings_providers.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GridColors.panel,
    constraints: const BoxConstraints(maxWidth: 430),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const SettingsSheet(),
  );
}

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider).value;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final auth = ref.watch(authProvider);

    final voices = [
      for (final v in config?.voices ?? const <VoiceOption>[])
        if (settings.voiceGender.isEmpty || v.gender == settings.voiceGender) v,
    ];
    final selectedVoice = voices.any((v) => v.name == settings.voice)
        ? settings.voice
        : (voices.any((v) => v.name == config?.defaultVoice)
              ? config?.defaultVoice
              : voices.firstOrNull?.name);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          28 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            if (auth.authRequired) ...[
              Text(
                'Signed in as ${auth.user?.name ?? ''}'
                '${auth.user?.role == null ? '' : ' (${auth.user!.roleLabel})'}',
                style: const TextStyle(fontSize: 12, color: GridColors.soft),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await ref.read(liveProvider.notifier).stop();
                  await ref.read(authProvider.notifier).logout();
                },
                child: const Text('Sign out'),
              ),
            ] else
              const _UserPicker(),
            _label('Reply language'),
            _Dropdown<String>(
              value: settings.replyLanguage,
              items: const {
                'auto': 'Same as I speak (automatic)',
                'en': 'Always English',
                'te': 'Always Telugu',
                'hi': 'Always Hindi',
                'kn': 'Always Kannada',
              },
              onChanged: notifier.setReplyLanguage,
            ),
            _label('Assistant voice'),
            _Dropdown<String>(
              value: settings.voiceGender,
              items: const {
                '': 'Any voice',
                'male': 'Male voices',
                'female': 'Female voices',
              },
              onChanged: notifier.setVoiceGender,
            ),
            const SizedBox(height: 8),
            if (voices.isNotEmpty && selectedVoice != null)
              _Dropdown<String>(
                value: selectedVoice,
                items: {for (final v in voices) v.name: v.label},
                onChanged: notifier.setVoice,
              ),
            _label('Speaking style'),
            if (config != null && config.styles.isNotEmpty)
              _Dropdown<String>(
                value: config.styles.any((s) => s.key == settings.style)
                    ? settings.style
                    : config.styles.first.key,
                items: {for (final s in config.styles) s.key: s.label},
                onChanged: notifier.setStyle,
              ),
            const _Note(
              'Voice and style apply the next time you tap the orb.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.bargeIn,
              onChanged: notifier.setBargeIn,
              title: const Text(
                'Let me interrupt by speaking',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const _Note(
              'While Grid is talking, start speaking and it stops and listens. '
              'You can also tap the orb to interrupt.',
            ),
            const SizedBox(height: 8),
            const _WakeSection(),
            const _VoiceSection(),
            const SizedBox(height: 8),
            const _Note(
              'Your voice is not transcribed. The answer is shown as captions '
              'and cards. Orders you confirm out loud are saved for real.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: GridColors.soft),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: GridColors.soft),
    ),
  );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: items.containsKey(value) ? value : null,
    isExpanded: true,
    dropdownColor: GridColors.panel,
    items: [
      for (final e in items.entries)
        DropdownMenuItem(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

/// Sign-in off (development): pick who to talk as.
class _UserPicker extends ConsumerWidget {
  const _UserPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    final notifier = ref.read(usersProvider.notifier);
    final current = ref.watch(authProvider.select((s) => s.user));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Talking as (development: no sign-in)',
          style: TextStyle(fontSize: 13, color: GridColors.soft),
        ),
        const SizedBox(height: 6),
        TextField(
          onChanged: notifier.setQuery,
          decoration: const InputDecoration(
            hintText: 'Search all users by name',
            prefixIcon: Icon(Icons.search, size: 18),
          ),
        ),
        const SizedBox(height: 8),
        _Dropdown<String>(
          value: users.role,
          items: {
            '': 'All roles',
            for (final r in users.result.roles)
              r.role: '${r.role.replaceAll('_', ' ').toLowerCase()} (${r.count})',
          },
          onChanged: notifier.setRole,
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: GridColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: users.loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView(
                  children: [
                    for (final p in users.result.people)
                      ListTile(
                        dense: true,
                        selected: p.key == current?.key,
                        title: Text(
                          '${p.name}${p.role == null ? '' : ' (${p.role})'}',
                        ),
                        onTap: () {
                          ref.read(authProvider.notifier).selectPerson(p);
                        },
                      ),
                  ],
                ),
        ),
        _Note(
          users.error ??
              (users.result.total > users.result.people.length
                  ? 'Showing ${users.result.people.length} of ${users.result.total}. Type to narrow the list.'
                  : '${users.result.total} found'),
        ),
      ],
    );
  }
}


/// "Hey Grid": wake word that runs in the browser.
class _WakeSection extends ConsumerWidget {
  const _WakeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.wake,
          onChanged: notifier.setWake,
          title: const Text(
            'Wake word: say "Hey Grid"',
            style: TextStyle(fontSize: 14),
          ),
        ),
        const _Note(
          'Grid waits for "Hey Grid" and starts listening. Nothing is sent '
          'anywhere while it waits.',
        ),
        if (settings.wake) ...[
          SettingsSheet._label(
            'Wake threshold (0.1 to 0.99; lower wakes more easily): '
            '${settings.wakeThreshold.toStringAsFixed(2)}',
          ),
          Slider(
            value: settings.wakeThreshold.clamp(0.1, 0.99),
            min: 0.1,
            max: 0.99,
            divisions: 89,
            onChanged: (v) =>
                notifier.setWakeThreshold((v * 20).round() / 20),
          ),
          SettingsSheet._label('Matches in a row needed'),
          _Dropdown<int>(
            value: settings.wakeNeed,
            items: {for (var i = 1; i <= 6; i++) i: '$i'},
            onChanged: notifier.setWakeNeed,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: WakeWord.downloadClip,
            child: const Text('Save last 3 s as WAV'),
          ),
        ],
      ],
    );
  }
}

/// Record, replace or delete the user's own voice.
class _VoiceSection extends ConsumerWidget {
  const _VoiceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(voiceprintProvider);
    final notifier = ref.read(voiceprintProvider.notifier);
    final name = ref.watch(authProvider.select((s) => s.user?.name)) ?? '';

    Future<void> startRecording({required bool replace}) async {
      if (replace) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Record a new voice?'),
            content: Text(
              'This replaces the saved voice for $name. Only the new voice '
              'will be accepted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Record'),
              ),
            ],
          ),
        );
        if (ok != true || !context.mounted) return;
      }
      Navigator.of(context).pop();
      notifier.record();
    }

    Future<void> confirmDelete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete saved voice?'),
          content: Text(
            'Delete the saved voice for $name? Anyone can wake Grid until '
            'you record again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) notifier.delete();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSheet._label('Voice setup language'),
        _Dropdown<String>(
          value: v.language,
          items: voiceLanguages,
          onChanged: notifier.setLanguage,
        ),
        if (!v.status.available)
          const _Note('Saved voices are not available on this server.')
        else if (v.status.saved) ...[
          _Note(
            'Your voice is saved for $name'
            '${v.status.quality == null ? '' : ' (quality ${v.status.quality})'}'
            '. Only this voice can wake Grid.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => startRecording(replace: true),
                  child: const Text('Re-record'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: confirmDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF9B9B),
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ] else ...[
          const _Note(
            'You read 3 short sentences. Only the numbers that describe '
            'your voice are kept, never the audio.',
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: v.consent,
            onChanged: (c) => notifier.setConsent(c ?? false),
            title: const Text(
              'I agree to keep my voiceprint (numbers only, no audio).',
              style: TextStyle(fontSize: 13),
            ),
          ),
          OutlinedButton(
            onPressed: () => startRecording(replace: false),
            child: const Text('Record my voice'),
          ),
        ],
        if (v.message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              v.message!,
              style: const TextStyle(color: Color(0xFFFF9B9B), fontSize: 12),
            ),
          ),
      ],
    );
  }
}
