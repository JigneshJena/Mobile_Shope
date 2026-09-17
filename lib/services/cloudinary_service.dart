import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

/// Handles image uploads to Cloudinary using an **unsigned** upload preset.
///
/// No API key or secret is embedded — the upload preset grants the required
/// permission server-side so secrets stay out of the client bundle.
class CloudinaryService {
  // ──────────────────────────────────────────────
  // Single image upload
  // ──────────────────────────────────────────────

  /// Uploads [imageFile] to Cloudinary.
  ///
  /// Returns the `secure_url` (HTTPS) on success, or `null` if the upload
  /// fails for any reason (network error, non-200 response, etc.).
  Future<String?> uploadImage(File imageFile) async {
    try {
      final url = Uri.parse(AppConstants.cloudinaryBaseUrl);

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = AppConstants.cloudinaryUploadPreset
        ..files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      }

      // Log the failure body for easier debugging in development.
      // ignore: avoid_print
      print('[CloudinaryService] Upload failed '
          '(${streamedResponse.statusCode}): $responseBody');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[CloudinaryService] uploadImage error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // Batch upload
  // ──────────────────────────────────────────────

  /// Uploads [imageFiles] concurrently.
  ///
  /// Returns only the URLs that succeeded; failed uploads are silently
  /// dropped from the result list.
  Future<List<String>> uploadImages(List<File> imageFiles) async {
    final results = await Future.wait(
      imageFiles.map((f) => uploadImage(f)),
    );
    // Filter out nulls with a type-safe whereType.
    return results.whereType<String>().toList();
  }
}
