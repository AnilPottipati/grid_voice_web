/// What the orb shows.
enum LivePhase {
  /// Not connected. "Tap to talk".
  idle,

  /// Connected and waiting for you to speak.
  listening,

  /// The assistant is working on the answer.
  thinking,

  /// The assistant's voice is playing.
  speaking,
}
