import 'package:cloud_firestore/cloud_firestore.dart';

enum PostPrivacy { public, followersOnly, onlyMe }

enum PostStatus { published, draft, archived }

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String userUsername;
  final String userProfilePhoto;
  final String content;
  final String? imageUrl;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final List<String> fileUrls;
  final List<String> tags;
  final PostPrivacy privacy;
  final PostStatus status;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;

  const PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userUsername,
    this.userProfilePhoto = '',
    required this.content,
    this.imageUrl,
    this.imageUrls = const [],
    this.videoUrls = const [],
    this.fileUrls = const [],
    this.tags = const [],
    this.privacy = PostPrivacy.public,
    this.status = PostStatus.published,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
  });

  factory PostModel.fromMap(Map<String, dynamic> map, String docId) {
    final parsedImageUrls =
        (map['imageUrls'] as List?)
            ?.map((e) => '$e'.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    final parsedVideoUrls =
        (map['videoUrls'] as List?)
            ?.map((e) => '$e'.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    final parsedFileUrls =
        (map['fileUrls'] as List?)
            ?.map((e) => '$e'.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    final parsedTags =
        (map['tags'] as List?)
            ?.map((e) => '$e'.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    final legacyImageUrl = (map['imageUrl'] as String?)?.trim();

    final combinedImageUrls = {
      ...parsedImageUrls,
      if ((legacyImageUrl ?? '').isNotEmpty) legacyImageUrl!,
    }.toList();

    return PostModel(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userUsername: map['userUsername'] ?? '',
      userProfilePhoto: map['userProfilePhoto'] ?? '',
      content: map['content'] ?? '',
      imageUrl: combinedImageUrls.isNotEmpty ? combinedImageUrls.first : null,
      imageUrls: combinedImageUrls,
      videoUrls: parsedVideoUrls,
      fileUrls: parsedFileUrls,
      tags: parsedTags,
      privacy: PostPrivacy.values.firstWhere(
        (e) => e.name == map['privacy'],
        orElse: () => PostPrivacy.public,
      ),
      status: PostStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PostStatus.published,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userUsername': userUsername,
      'userProfilePhoto': userProfilePhoto,
      'content': content,
      'imageUrl': primaryImageUrl,
      'imageUrls': allImageUrls,
      'videoUrls': videoUrls,
      'fileUrls': fileUrls,
      'tags': tags,
      'privacy': privacy.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
    };
  }

  PostModel copyWith({
    String? content,
    String? imageUrl,
    List<String>? imageUrls,
    List<String>? videoUrls,
    List<String>? fileUrls,
    List<String>? tags,
    PostPrivacy? privacy,
    PostStatus? status,
    int? likesCount,
    int? commentsCount,
    String? userName,
    String? userUsername,
    String? userProfilePhoto,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      userName: userName ?? this.userName,
      userUsername: userUsername ?? this.userUsername,
      userProfilePhoto: userProfilePhoto ?? this.userProfilePhoto,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrls: videoUrls ?? this.videoUrls,
      fileUrls: fileUrls ?? this.fileUrls,
      tags: tags ?? this.tags,
      privacy: privacy ?? this.privacy,
      status: status ?? this.status,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }

  List<String> get allImageUrls {
    if (imageUrls.isNotEmpty) return imageUrls;
    if ((imageUrl ?? '').trim().isNotEmpty) return [imageUrl!.trim()];
    return const [];
  }

  String? get primaryImageUrl =>
      allImageUrls.isNotEmpty ? allImageUrls.first : null;
}
