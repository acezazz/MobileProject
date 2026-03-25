import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminPostsScreen extends StatelessWidget {
  const AdminPostsScreen({super.key});

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const int _warningLimit = 3;

  static final Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream = _db
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();

  Future<void> _recordAdminNotification({
    required String type,
    required String title,
    required String body,
    String? postId,
    String? targetUserId,
    String? targetUserLabel,
  }) async {
    await _db.collection('admin_notifications').add({
      'type': type,
      'title': title,
      'body': body,
      'postId': postId,
      'targetUserId': targetUserId,
      'targetUserLabel': targetUserLabel,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.uid,
      'read': false,
    });
  }

  Future<String> _resolveUserLabel(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data() ?? const <String, dynamic>{};

    final name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final username = (data['username'] ?? '').toString().trim();
    if (username.isNotEmpty) return '@$username';

    final suffix = userId.length >= 6 ? userId.substring(0, 6) : userId;
    return 'User $suffix';
  }

  Future<void> _notifyUserViolation({
    required String userId,
    required String postId,
    required int warningCount,
    required bool suspended,
  }) async {
    await _db.collection('users').doc(userId).collection('notifications').add({
      'type': suspended ? 'suspension' : 'warning',
      'postId': postId,
      'title': suspended ? 'Account Suspended' : 'Post Removed',
      'message': suspended
          ? 'Your account has been suspended for 7 days due to repeated violations.'
          : 'Your post violated our community guidelines. This is warning $warningCount/$_warningLimit.',
      'warningCount': warningCount,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<({int warningCount, bool suspended})> _applyViolationToUser({
    required String targetUserId,
    required String reason,
  }) async {
    final userRef = _db.collection('users').doc(targetUserId);
    final adminId = _auth.currentUser?.uid;

    var nextWarnings = 0;
    var suspended = false;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final current = snapshot.data() ?? <String, dynamic>{};
      final currentWarningsRaw =
          current['warningCount'] ?? current['warningsCount'];
      final currentWarnings = (currentWarningsRaw is num)
          ? currentWarningsRaw.toInt()
          : 0;
      final currentStrikes = (current['strikesCount'] is num)
          ? (current['strikesCount'] as num).toInt()
          : 0;

      nextWarnings = currentWarnings + 1;
      suspended = nextWarnings >= _warningLimit;

      final patch = <String, dynamic>{
        'warningCount': nextWarnings,
        'warningsCount': nextWarnings,
        'strikesCount': currentStrikes + 1,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByAdminId': adminId,
      };

      if (suspended) {
        final suspensionEnd = DateTime.now().add(const Duration(days: 7));
        patch.addAll({
          'isSuspended': true,
          'status': 'suspended',
          'suspensionType': 'temporary',
          'suspensionUntil': Timestamp.fromDate(suspensionEnd),
          'suspensionEnd': Timestamp.fromDate(suspensionEnd),
          'suspensionReason':
              'Automatic moderation: reached $_warningLimit warnings ($reason)',
          'suspendedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(userRef, patch, SetOptions(merge: true));
    });

    return (warningCount: nextWarnings, suspended: suspended);
  }

  Future<void> _applyViolationFlow({
    required BuildContext context,
    required String postId,
    required String postOwnerId,
    required String postStatus,
    required String reason,
  }) async {
    if (postOwnerId.trim().isEmpty) return;
    try {
      await _db.collection('posts').doc(postId).update({
        'status': postStatus,
        'moderationReason': reason,
        'moderatedAt': FieldValue.serverTimestamp(),
        'moderatedBy': _auth.currentUser?.uid,
      });

      final targetLabel = await _resolveUserLabel(postOwnerId);

      final result = await _applyViolationToUser(
        targetUserId: postOwnerId,
        reason: reason,
      );

      await _notifyUserViolation(
        userId: postOwnerId,
        postId: postId,
        warningCount: result.warningCount,
        suspended: result.suspended,
      );

      await _recordAdminNotification(
        type: result.suspended ? 'account_suspended' : 'warning_issued',
        title: result.suspended
            ? 'Account suspended after repeated violations'
            : 'Post violation warning issued',
        body: result.suspended
            ? '$targetLabel reached $_warningLimit warnings and was suspended for 7 days.'
            : '$targetLabel now has ${result.warningCount}/$_warningLimit warnings.',
        postId: postId,
        targetUserId: postOwnerId,
        targetUserLabel: targetLabel,
      );

      if (!context.mounted) return;
      final suffix = result.suspended
          ? ' Account suspended for 7 days.'
          : ' Warning ${result.warningCount}/$_warningLimit issued.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Moderation applied.$suffix')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to apply moderation: $e')));
    }
  }

  Widget _buildPreview(Map<String, dynamic> data) {
    final imageUrls =
        (data['imageUrls'] as List?)
            ?.map((item) => '$item'.trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];
    final legacyImage = (data['imageUrl'] as String?)?.trim() ?? '';
    final previewImage = imageUrls.isNotEmpty
        ? imageUrls.first
        : (legacyImage.isNotEmpty ? legacyImage : '');

    final hasVideo = ((data['videoUrls'] as List?) ?? const []).isNotEmpty;
    final hasFile = ((data['fileUrls'] as List?) ?? const []).isNotEmpty;

    if (previewImage.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: previewImage,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          placeholder: (_, _) => const SizedBox(
            width: 54,
            height: 54,
            child: ColoredBox(color: Colors.black12),
          ),
          errorWidget: (_, _, _) => const SizedBox(
            width: 54,
            height: 54,
            child: ColoredBox(
              color: Colors.black12,
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        hasVideo
            ? Icons.play_circle_outline
            : hasFile
            ? Icons.attach_file
            : Icons.text_fields,
      ),
    );
  }

  Future<void> _updatePostStatus({
    required BuildContext context,
    required String postId,
    required String status,
    String? moderationReason,
  }) async {
    try {
      final patch = <String, dynamic>{'status': status};
      if (status == 'suspended' || status == 'archived') {
        patch['moderationReason'] =
            (moderationReason?.trim().isNotEmpty ?? false)
            ? moderationReason!.trim()
            : 'Moderated by admin';
        patch['moderatedAt'] = FieldValue.serverTimestamp();
        patch['moderatedBy'] = _auth.currentUser?.uid;
      }
      if (status == 'published') {
        patch['moderationReason'] = null;
      }

      await _db.collection('posts').doc(postId).update(patch);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Post marked as $status.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update post: $e')));
    }
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posts Monitoring')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No posts found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final postId = docs[index].id;
              final author =
                  (data['userUsername'] ?? data['userName'] ?? 'user')
                      .toString();
              final content = (data['content'] ?? '').toString().trim();
              final status = (data['status'] ?? 'unknown').toString();
              final privacy = (data['privacy'] ?? 'public').toString();
              final createdAt = data['createdAt'];
              final postOwnerId = (data['userId'] ?? '').toString();
              final isModerated = status == 'archived' || status == 'suspended';
              final createdLabel = createdAt is Timestamp
                  ? createdAt.toDate().toLocal().toString()
                  : 'Unknown time';

              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: _buildPreview(data),
                  title: Text('@$author'),
                  subtitle: Text(
                    '${content.isEmpty ? '(no text)' : content}\n'
                    'status: $status • privacy: $privacy\n'
                    '$createdLabel',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Open post',
                        onPressed: () => context.push('/post/$postId'),
                        icon: const Icon(Icons.open_in_new),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Post actions',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'archive') {
                            final confirmed = await _confirmAction(
                              context,
                              title: 'Suspend post for violation?',
                              message:
                                  'This post will be hidden and the user will receive a policy warning. Account suspension only happens at $_warningLimit warnings.',
                              confirmLabel: 'Suspend',
                            );
                            if (!confirmed) return;
                            await _applyViolationFlow(
                              context: context,
                              postId: postId,
                              postOwnerId: postOwnerId,
                              postStatus: 'suspended',
                              reason: 'Post suspended by admin moderation',
                            );
                            return;
                          }

                          if (value == 'restore') {
                            final confirmed = await _confirmAction(
                              context,
                              title: 'Restore post?',
                              message:
                                  'This post will be restored as published.',
                              confirmLabel: 'Restore',
                            );
                            if (!confirmed) return;
                            await _updatePostStatus(
                              context: context,
                              postId: postId,
                              status: 'published',
                              moderationReason: null,
                            );
                            return;
                          }

                          if (value == 'delete') {
                            final confirmed = await _confirmAction(
                              context,
                              title: 'Archive post for severe violation?',
                              message:
                                  'This post will be archived and the user will receive a violation warning.',
                              confirmLabel: 'Archive',
                            );
                            if (!confirmed) return;
                            await _applyViolationFlow(
                              context: context,
                              postId: postId,
                              postOwnerId: postOwnerId,
                              postStatus: 'archived',
                              reason: 'Post archived by admin moderation',
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: isModerated ? 'restore' : 'archive',
                            child: Text(
                              isModerated
                                  ? 'Restore post'
                                  : 'Suspend post (violation)',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Archive post + warn user'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => context.push('/post/$postId'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
