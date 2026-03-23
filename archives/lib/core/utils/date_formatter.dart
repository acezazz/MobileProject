import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class DateFormatter {
  DateFormatter._();

  static String relative(DateTime dateTime) {
    return timeago.format(dateTime, allowFromNow: true);
  }

  static String full(DateTime dateTime) {
    return DateFormat("MMM d, yyyy 'at' h:mm a").format(dateTime);
  }

  static String shortDate(DateTime dateTime) {
    return DateFormat('MMM d').format(dateTime);
  }

  static String chatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays == 0) return DateFormat('h:mm a').format(dateTime);
    if (diff.inDays < 7) return DateFormat('EEE').format(dateTime);
    return DateFormat('MM/dd/yy').format(dateTime);
  }

  static DateTime fromTimestamp(Timestamp timestamp) {
    return timestamp.toDate();
  }
}
