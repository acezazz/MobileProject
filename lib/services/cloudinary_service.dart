import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get uploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static String _uploadUrl(String resourceType) =>
      'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload';

  static Future<String?> _uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String resourceType,
    String? folder,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_uploadUrl(resourceType)),
    );

    request.fields['upload_preset'] = uploadPreset;
    if (folder != null) {
      request.fields['folder'] = folder;
    }

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);
      return jsonData['secure_url'] as String;
    }

    final responseData = await response.stream.bytesToString();
    throw Exception('Upload failed (${response.statusCode}): $responseData');
  }

  static Future<String?> uploadImage({
    required Uint8List imageBytes,
    required String fileName,
    String? folder,
  }) async {
    try {
      return _uploadBytes(
        bytes: imageBytes,
        fileName: fileName,
        resourceType: 'image',
        folder: folder,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> uploadVideo({
    required Uint8List videoBytes,
    required String fileName,
    String? folder,
  }) async {
    try {
      return _uploadBytes(
        bytes: videoBytes,
        fileName: fileName,
        resourceType: 'video',
        folder: folder,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> uploadRawFile({
    required Uint8List fileBytes,
    required String fileName,
    String? folder,
  }) async {
    try {
      return _uploadBytes(
        bytes: fileBytes,
        fileName: fileName,
        resourceType: 'raw',
        folder: folder,
      );
    } catch (e) {
      rethrow;
    }
  }
}
