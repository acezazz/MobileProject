import 'package:archives/core/constants/firestore_constants.dart';
import 'package:archives/services/chat_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setMessageReaction stores reaction by user', () async {
    final firestore = FakeFirebaseFirestore();
    final service = ChatService(firestore: firestore);

    await firestore.collection(FirestoreConstants.chatsCollection).doc('c1').set({
      'participants': ['u1', 'u2'],
      'isGroup': false,
      'createdAt': DateTime.now(),
      'lastMessageTime': DateTime.now(),
    });

    await firestore
        .collection(FirestoreConstants.chatsCollection)
        .doc('c1')
        .collection(FirestoreConstants.messagesSubcollection)
        .doc('m1')
        .set({
          'chatId': 'c1',
          'senderId': 'u1',
          'senderName': 'A',
          'content': 'hello',
          'isDeletedForEveryone': false,
          'createdAt': DateTime.now(),
        });

    await service.setMessageReaction(
      chatId: 'c1',
      messageId: 'm1',
      currentUserId: 'u2',
      emoji: '😀',
    );

    final doc = await firestore
        .collection(FirestoreConstants.chatsCollection)
        .doc('c1')
        .collection(FirestoreConstants.messagesSubcollection)
        .doc('m1')
        .get();

    expect(doc.data()?['reactions']['u2'], '😀');
  });

  test('removeMessageReaction removes reaction key for user', () async {
    final firestore = FakeFirebaseFirestore();
    final service = ChatService(firestore: firestore);

    await firestore.collection(FirestoreConstants.chatsCollection).doc('c1').set({
      'participants': ['u1', 'u2'],
      'isGroup': false,
      'createdAt': DateTime.now(),
      'lastMessageTime': DateTime.now(),
    });

    await firestore
        .collection(FirestoreConstants.chatsCollection)
        .doc('c1')
        .collection(FirestoreConstants.messagesSubcollection)
        .doc('m1')
        .set({
          'chatId': 'c1',
          'senderId': 'u1',
          'senderName': 'A',
          'content': 'hello',
          'isDeletedForEveryone': false,
          'reactions': {'u2': '😀'},
          'createdAt': DateTime.now(),
        });

    await service.removeMessageReaction(
      chatId: 'c1',
      messageId: 'm1',
      currentUserId: 'u2',
    );

    final doc = await firestore
        .collection(FirestoreConstants.chatsCollection)
        .doc('c1')
        .collection(FirestoreConstants.messagesSubcollection)
        .doc('m1')
        .get();

    expect((doc.data()?['reactions'] ?? {}).containsKey('u2'), false);
  });
}
