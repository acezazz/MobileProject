import 'package:archives/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleted message cannot receive reactions', () {
    final active = MessageModel(
      id: 'm1',
      chatId: 'c1',
      senderId: 'u1',
      senderName: 'A',
      content: 'hello',
      createdAt: DateTime(2026, 1, 1),
    );

    final deleted = MessageModel(
      id: 'm2',
      chatId: 'c1',
      senderId: 'u1',
      senderName: 'A',
      content: 'This message was deleted',
      isDeletedForEveryone: true,
      createdAt: DateTime(2026, 1, 1),
    );

    expect(active.canReceiveReactions, true);
    expect(deleted.canReceiveReactions, false);
  });
}
