import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'voiceprint_notifier.dart';

/// Shown over the screen while the user reads the three sentences.
class VoiceSetupOverlay extends ConsumerWidget {
  const VoiceSetupOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(voiceprintProvider);
    if (!v.recording) return const SizedBox.shrink();
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xE6000000),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GridColors.panel,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: GridColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record my voice',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  v.step,
                  style: const TextStyle(fontSize: 12, color: GridColors.soft),
                ),
                const SizedBox(height: 10),
                if (v.sentence.isNotEmpty)
                  Text(
                    v.sentence,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: v.progress),
                const SizedBox(height: 8),
                Text(
                  v.hearing
                      ? 'Hearing you.'
                      : 'Too quiet: speak a little louder or move closer.',
                  style: const TextStyle(fontSize: 12, color: GridColors.soft),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: ref.read(voiceprintProvider.notifier).skip,
                    child: const Text('Cancel'),
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
