import 'package:share_plus/share_plus.dart';

class PostShareService {
  static Future<void> sharePostUrl(String postId) {
    return Share.share('Check this post on Archives: /post/$postId');
  }
}
