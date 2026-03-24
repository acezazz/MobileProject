import 'dart:async';

import 'package:archives/models/chat_model.dart';
import 'package:archives/models/message_model.dart';
import 'package:archives/providers/auth_providers.dart';
import 'package:archives/providers/chat_providers.dart';
import 'package:archives/repositories/chat_repository.dart';
import 'package:archives/screens/chat/chat_screen.dart';
import 'package:archives/services/chat_service.dart';
import 'package:archives/widgets/chat/emoji_reaction_picker.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long press message opens reaction picker', (tester) async {
    final controller = StreamController<List<MessageModel>>.broadcast();
    addTearDown(controller.close);

    var messages = [_message(reactions: const {})];
    final fakeRepo = _FakeChatRepository(
      onSetReaction:
          ({
            required chatId,
            required messageId,
            required currentUserId,
            required emoji,
          }) {
            messages = [
              _message(reactions: {currentUserId: emoji}),
            ];
            controller.add(messages);
          },
      onRemoveReaction:
          ({required chatId, required messageId, required currentUserId}) {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
          chatMessagesProvider.overrideWith((ref, chatId) => controller.stream),
          chatInfoProvider.overrideWith((ref, chatId) async => _chatModel()),
        ],
        child: const MaterialApp(
          home: ChatScreen(chatId: 'c1', currentUserIdOverride: 'u1'),
        ),
      ),
    );
    controller.add(messages);
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.longPress(find.text('hello'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('React'));
    await tester.pumpAndSettle();

    expect(find.byType(EmojiReactionPicker), findsOneWidget);
  });

  testWidgets('tapping own reaction chip removes reaction', (tester) async {
    final controller = StreamController<List<MessageModel>>.broadcast();
    addTearDown(controller.close);

    var messages = [
      _message(reactions: const {'u1': '😀'}),
    ];

    var removeCalls = 0;
    final fakeRepo = _FakeChatRepository(
      onSetReaction:
          ({
            required chatId,
            required messageId,
            required currentUserId,
            required emoji,
          }) {},
      onRemoveReaction:
          ({required chatId, required messageId, required currentUserId}) {
            removeCalls++;
            messages = [_message(reactions: const {})];
            controller.add(messages);
          },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
          chatMessagesProvider.overrideWith((ref, chatId) => controller.stream),
          chatInfoProvider.overrideWith((ref, chatId) async => _chatModel()),
        ],
        child: const MaterialApp(
          home: ChatScreen(chatId: 'c1', currentUserIdOverride: 'u1'),
        ),
      ),
    );
    controller.add(messages);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('😀 1'), findsOneWidget);

    await tester.tap(find.text('😀 1'));
    await tester.pumpAndSettle();

    expect(removeCalls, 1);
    expect(find.text('😀 1'), findsNothing);
  });
}

class _FakeChatRepository extends ChatRepository {
  final void Function({
    required String chatId,
    required String messageId,
    required String currentUserId,
    required String emoji,
  })
  onSetReaction;

  final void Function({
    required String chatId,
    required String messageId,
    required String currentUserId,
  })
  onRemoveReaction;

  _FakeChatRepository({
    required this.onSetReaction,
    required this.onRemoveReaction,
  }) : super(chatService: ChatService(firestore: FakeFirebaseFirestore()));

  @override
  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String currentUserId,
    required String emoji,
  }) async {
    onSetReaction(
      chatId: chatId,
      messageId: messageId,
      currentUserId: currentUserId,
      emoji: emoji,
    );
  }

  @override
  Future<void> removeMessageReaction({
    required String chatId,
    required String messageId,
    required String currentUserId,
  }) async {
    onRemoveReaction(
      chatId: chatId,
      messageId: messageId,
      currentUserId: currentUserId,
    );
  }

  @override
  Future<void> markMessagesAsSeen(String chatId, String currentUserId) async {}
}

ChatModel _chatModel() {
  return ChatModel(
    id: 'c1',
    participants: const ['u1', 'u2'],
    isGroup: true,
    groupName: 'Group',
    lastMessageTime: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

MessageModel _message({required Map<String, String> reactions}) {
  return MessageModel(
    id: 'm1',
    chatId: 'c1',
    senderId: 'u2',
    senderName: 'User Two',
    content: 'hello',
    reactions: reactions,
    createdAt: DateTime(2026, 1, 1),
    status: MessageStatus.seen,
  );
}
