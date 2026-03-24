import 'package:archives/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MessageModel parses reactions map safely', () {
    final model = MessageModel.fromMap({
      'chatId': 'c1',
      'senderId': 'u1',
      'senderName': 'A',
      'content': 'hello',
      'reactions': {'u2': '😀'},
    }, 'm1');

    expect(model.reactions['u2'], '😀');
    expect(model.canReceiveReactions, true);
  });
}
