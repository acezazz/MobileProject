import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Map<String, Future<String?>> _userLabelFutures = {};

  static final Stream<QuerySnapshot<Map<String, dynamic>>>
  _notificationsStream = _db
      .collection('admin_notifications')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();

  static Future<String?> _targetUserLabel(String userId) {
    return _userLabelFutures.putIfAbsent(userId, () async {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? const <String, dynamic>{};
      final name = (data['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
      final username = (data['username'] ?? '').toString().trim();
      if (username.isNotEmpty) return '@$username';
      return null;
    });
  }

  static String _resolvedBody({
    required String rawBody,
    required String targetUserId,
    required String? targetUserLabel,
  }) {
    if (rawBody.isEmpty || targetUserId.isEmpty || targetUserLabel == null) {
      return rawBody;
    }
    return rawBody.replaceAll(targetUserId, targetUserLabel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No admin notifications yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final title = (data['title'] ?? 'Notification').toString();
              final rawBody = (data['body'] ?? '').toString();
              final type = (data['type'] ?? 'general').toString();
              final targetUserId = (data['targetUserId'] ?? '').toString();
              final storedTargetLabel = (data['targetUserLabel'] ?? '')
                  .toString()
                  .trim();
              final createdAt = data['createdAt'];
              final createdLabel = createdAt is Timestamp
                  ? createdAt.toDate().toLocal().toString()
                  : 'Unknown time';
              final unread = data['read'] != true;

              final bodyFuture = storedTargetLabel.isNotEmpty
                  ? Future<String>.value(
                      _resolvedBody(
                        rawBody: rawBody,
                        targetUserId: targetUserId,
                        targetUserLabel: storedTargetLabel,
                      ),
                    )
                  : (targetUserId.isEmpty
                        ? Future<String>.value(rawBody)
                        : _targetUserLabel(targetUserId).then(
                            (label) => _resolvedBody(
                              rawBody: rawBody,
                              targetUserId: targetUserId,
                              targetUserLabel: label,
                            ),
                          ));

              return FutureBuilder<String>(
                future: bodyFuture,
                builder: (context, bodySnapshot) {
                  final body = bodySnapshot.data ?? rawBody;
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          unread
                              ? Icons.notifications_active
                              : Icons.notifications,
                        ),
                      ),
                      title: Text(title),
                      subtitle: Text('$body\n$type • $createdLabel'),
                      isThreeLine: true,
                      trailing: unread
                          ? TextButton(
                              onPressed: () async {
                                await docs[index].reference.update({
                                  'read': true,
                                });
                              },
                              child: const Text('Mark read'),
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
