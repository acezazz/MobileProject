import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Picks an image using image_picker (works on web, iOS, Android).
/// Returns (bytes, fileName) or (null, null) if cancelled.
Future<(Uint8List?, String?)> pickImageFromBrowser() async {
  try {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      return (bytes, image.name);
    }
  } catch (e) {
    // Return empty on exception (e.g., permission denied)
  }
  return (null, null);
}

/// Picks multiple images using image_picker.
/// Returns list of (bytes, fileName). Empty list if cancelled.
Future<List<({Uint8List bytes, String name})>> pickImagesFromBrowser({
  int? maxImages,
}) async {
  try {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return const [];

    final picked = <({Uint8List bytes, String name})>[];
    final source = maxImages == null ? images : images.take(maxImages);
    for (final image in source) {
      final bytes = await image.readAsBytes();
      picked.add((bytes: bytes, name: image.name));
    }
    return picked;
  } catch (_) {
    return const [];
  }
}
