import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
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

/// Picks one or more GIF files.
Future<List<({Uint8List bytes, String name})>> pickGifsFromBrowser({
  int? maxFiles,
}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['gif'],
    );
    if (result == null || result.files.isEmpty) return const [];

    final picked = <({Uint8List bytes, String name})>[];
    final source = maxFiles == null
        ? result.files
        : result.files.take(maxFiles);
    for (final file in source) {
      final bytes = file.bytes;
      if (bytes != null) {
        picked.add((bytes: bytes, name: file.name));
      }
    }

    return picked;
  } catch (_) {
    return const [];
  }
}

/// Picks a single video file (for post composer).
/// Returns (bytes, fileName, path) or (null, null, null) if cancelled.
Future<(Uint8List?, String?, String?)> pickVideoFromBrowser() async {
  try {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final bytes = await video.readAsBytes();
      return (bytes, video.name, video.path);
    }
  } catch (_) {
    // Return empty on exception.
  }
  return (null, null, null);
}

/// Picks one or more generic files.
/// Returns list of (bytes, fileName). Empty list if cancelled.
Future<List<({Uint8List bytes, String name})>> pickFilesFromBrowser({
  int? maxFiles,
}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return const [];

    final picked = <({Uint8List bytes, String name})>[];
    final source = maxFiles == null
        ? result.files
        : result.files.take(maxFiles);
    for (final file in source) {
      final bytes = file.bytes;
      if (bytes != null) {
        picked.add((bytes: bytes, name: file.name));
      }
    }

    return picked;
  } catch (_) {
    return const [];
  }
}
