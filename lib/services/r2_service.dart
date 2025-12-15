import 'package:minio/minio.dart';
import '../constants.dart';

class R2Service {
  late Minio minio;

  R2Service() {
    String cleanEndpoint = AppConstants.r2EndpointUrl.replaceAll('https://', '');
    if (cleanEndpoint.endsWith('/')) {
      cleanEndpoint = cleanEndpoint.substring(0, cleanEndpoint.length - 1);
    }

    minio = Minio(
      endPoint: cleanEndpoint,
      accessKey: AppConstants.r2AccessKey,
      secretKey: AppConstants.r2SecretKey,
      useSSL: true,
      region: 'auto',
    );
  }

  // --- NEW FUNCTION ---
  Future<String?> getPresignedUrl(String objectKey) async {
    if (objectKey.isEmpty) return null;
    try {
      // Generates a secure link valid for 1 hour (3600 seconds)
      String url = await minio.presignedGetObject(
        AppConstants.r2BucketName, 
        objectKey, 
        expires: 3600
      );
      return url;
    } catch (e) {
      print("Error generating preview URL: $e");
      return null;
    }
  }
  // --------------------

  Future<void> deleteFile(String objectKey) async {
    // ... (Your existing delete code) ...
     if (objectKey.isEmpty) return;
    
    try {
      print("Deleting $objectKey from R2 bucket: ${AppConstants.r2BucketName}");
      await minio.removeObject(AppConstants.r2BucketName, objectKey);
      print("Success.");
    } catch (e) {
      print("R2 Delete Error: $e");
    }
  }
}