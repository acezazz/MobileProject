import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  static Future<String?> uploadImage({
    required Uint8List imageBytes,
    required String fileName,
    String? folder,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields['upload_preset'] = uploadPreset;
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: fileName),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        return jsonData['secure_url'] as String;
      } else {
        final responseData = await response.stream.bytesToString();
        throw Exception(
          'Upload failed (${response.statusCode}): $responseData',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
