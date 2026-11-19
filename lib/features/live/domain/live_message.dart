import 'dart:convert';

/// A text message from the server on the live socket (audio comes separately
/// as binary).
sealed class LiveMessage {
  const LiveMessage();

  /// Null for messages this app does not know.
  static LiveMessage? parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final m = decoded;
    switch (m['type']) {
      case 'ready':
        return const ReadyMessage();
      case 'gate':
        if (m['error'] != null) return ErrorMessage('${m['error']}');
        final score = m['score'];
        final need = m['need'];
        return GateMessage(
          '${m['event']}',
          score: score == null ? null : '$score',
          need: need == null ? null : '$need',
        );
      case 'tool_start':
        return ToolStartMessage('${m['name']}');
      case 'tool':
        return const ToolDoneMessage();
      case 'said':
        return SaidMessage('${m['text'] ?? ''}');
      case 'card':
        final card = m['card'];
        return card is Map<String, dynamic> ? CardMessage(card) : null;
      case 'interrupted':
        return const InterruptedMessage();
      case 'turn_complete':
        return const TurnCompleteMessage();
      case 'error':
        return ErrorMessage('${m['message'] ?? 'Something went wrong.'}');
    }
    return null;
  }
}

class ReadyMessage extends LiveMessage {
  const ReadyMessage();
}

/// Speech gate: `start_speech`, `end_speech`, `accepted`, `ignored`.
class GateMessage extends LiveMessage {
  const GateMessage(this.event, {this.score, this.need});

  final String event;
  final String? score;
  final String? need;
}

class ToolStartMessage extends LiveMessage {
  const ToolStartMessage(this.name);

  final String name;
}

class ToolDoneMessage extends LiveMessage {
  const ToolDoneMessage();
}

class SaidMessage extends LiveMessage {
  const SaidMessage(this.text);

  final String text;
}

class CardMessage extends LiveMessage {
  const CardMessage(this.card);

  final Map<String, dynamic> card;
}

class InterruptedMessage extends LiveMessage {
  const InterruptedMessage();
}

class TurnCompleteMessage extends LiveMessage {
  const TurnCompleteMessage();
}

class ErrorMessage extends LiveMessage {
  const ErrorMessage(this.message);

  final String message;

  bool get isSignInProblem => RegExp('sign in', caseSensitive: false).hasMatch(message);
}
