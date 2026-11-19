/// One thing in the conversation list.
sealed class ChatItem {
  const ChatItem();
}

/// The assistant's words, written as it speaks.
class CaptionItem extends ChatItem {
  const CaptionItem(this.text);

  final String text;

  CaptionItem append(String more) => CaptionItem(text + more);
}

/// A card drawn from the data behind an answer. [data] is the server's JSON.
class CardItem extends ChatItem {
  const CardItem(this.data);

  final Map<String, dynamic> data;

  String get kind => '${data['kind']}';
}

/// A small centered note ("Stopped after 5 quiet minutes").
class NoteItem extends ChatItem {
  const NoteItem(this.text);

  final String text;
}
