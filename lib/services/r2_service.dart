import 'package:minio/minio.dart';
import '../constants.dart';

class R2Service {
  late Minio minio;

  R2Service() {
    // 1. Clean the endpoint correctly
    String cleanEndpoint = AppConstants.r2EndpointUrl
        .replaceAll('https://', '')
        .replaceAll('http://', ''); // Remove both protocols just in case
    
    if (cleanEndpoint.endsWith('/')) {
      cleanEndpoint = cleanEndpoint.substring(0, cleanEndpoint.length - 1);
    }

    // 2. Initialize Minio with explicit HTTPS and Region
    minio = Minio(
      endPoint: cleanEndpoint,
      accessKey: AppConstants.r2AccessKey,
      secretKey: AppConstants.r2SecretKey,
      useSSL: true, // <--- This forces HTTPS generation automatically
      region: 'auto', // R2 uses 'auto', but if this fails, try 'us-east-1'
    );
  }

  Future<String?> getPresignedUrl(String objectKey) async {
    if (objectKey.isEmpty) return null;
    try {
      // 3. Generate the URL without manual tampering
      String url = await minio.presignedGetObject(
        AppConstants.r2BucketName, 
        objectKey, 
        expires: 3600 // 1 hour validity
      );

      print("DEBUG: Generated Valid R2 URL: $url");
      return url;
    } catch (e) {
      print("Error generating preview URL: $e");
      return null;
    }
  }

  Future<void> deleteFile(String objectKey) async {
     if (objectKey.isEmpty) return;
    try {
      await minio.removeObject(AppConstants.r2BucketName, objectKey);
      print("Deleted $objectKey successfully.");
    } catch (e) {
      print("R2 Delete Error: $e");
    }
  }
}