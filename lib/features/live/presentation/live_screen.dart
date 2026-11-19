import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/orb.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../settings/presentation/settings_sheet.dart';
import '../../voice/presentation/voice_setup_overlay.dart';
import '../domain/chat_item.dart';
import 'card_view.dart';
import 'live_notifier.dart';

/// The main screen: who you are talking as, the conversation, and the orb.
class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(liveProvider.select((s) => s.message));
    return Stack(
      children: [
        const Column(
          children: [
            _Header(),
            Expanded(child: _Conversation()),
            _Dock(),
          ],
        ),
        const VoiceSetupOverlay(),
        if (message != null)
          Positioned(
            left: 16,
            right: 16,
            top: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1A1F),
                border: Border.all(color: const Color(0xFF5A2A33)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFFFD5DA),
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.4, -0.4),
                colors: [Color(0xFF9FD4FF), GridColors.accent, GridColors.accent2],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Grid',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  user == null ? 'No users' : 'Talking as ${user.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: GridColors.soft),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: 'Settings',
            onPressed: () => showSettingsSheet(context),
            icon: const Icon(Icons.settings, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: GridColors.panel,
              side: const BorderSide(color: GridColors.line),
            ),
          ),
        ],
      ),
    );
  }
}

class _Conversation extends ConsumerStatefulWidget {
  const _Conversation();

  @override
  ConsumerState<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<_Conversation> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(liveProvider.select((s) => s.items));
    ref.listen(liveProvider.select((s) => s.items), (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });
    if (items.isEmpty) return const _Hello();
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) => switch (items[i]) {
        CaptionItem(:final text) => _Bubble(text),
        final CardItem card => CardView(item: card),
        NoteItem(:final text) => _Note(text),
      },
    );
  }
}

class _Hello extends StatelessWidget {
  const _Hello();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Hi, I'm Grid",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Tap the glowing button and just speak. Your voice goes straight '
            'to the assistant, which answers from your own orders, targets and '
            'products. Speak in English, Hindi or Telugu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: GridColors.soft),
          ),
        ],
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.92,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: GridColors.panel,
          border: Border.all(color: GridColors.line),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(5),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.45)),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: GridColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: GridColors.soft),
      ),
    ),
  );
}

class _Dock extends ConsumerWidget {
  const _Dock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(liveProvider.select((s) => s.statusText));
    final phase = ref.watch(liveProvider.select((s) => s.phase));
    final level = ref.watch(liveProvider.select((s) => s.level));
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: GridColors.soft),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => ref.read(liveProvider.notifier).toggle(),
            child: Orb(phase: phase, level: level),
          ),
        ],
      ),
    );
  }
}
