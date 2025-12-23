import 'dart:io';
import 'dart:async';
import 'package:minio/minio.dart';
import 'package:minio/models.dart';
import 'package:minio/io.dart';
import '../constants.dart';

class R2Service {
  late Minio minio;

  R2Service() {
    String cleanEndpoint = AppConstants.r2EndpointUrl
        .replaceAll('https://', '')
        .replaceAll('http://', '');
    
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

  // --- DOWNLOAD STREAM (Fix: Safe File Size Check) ---
  Future<File?> downloadStream(
    String objectKey, 
    String savePath, 
    {String? bucketName, Function(double)? onProgress}
  ) async {
    try {
      final targetBucket = bucketName ?? AppConstants.r2BucketName;
      
      // 1. Try to get File Size (Safely)
      int totalBytes = 0;
      try {
        var stat = await minio.statObject(targetBucket, objectKey);
        totalBytes = stat.size ?? 0;
      } catch (e) {
        print("⚠️ Warning: Could not get file size (Progress bar will be indeterminate): $e");
        // We ignore the error and proceed to download anyway!
      }

      print("⬇️ Downloading '$objectKey'...");

      // 2. Get Data Stream
      Stream<List<int>> stream = await minio.getObject(targetBucket, objectKey);

      final controller = StreamController<List<int>>();
      stream.listen(
        (chunk) {
          receivedBytes += chunk.length;
          // Only update progress if we managed to get the total size
          if (totalBytes > 0 && onProgress != null) {
            onProgress(receivedBytes / totalBytes);
          }
          controller.add(chunk);
        },
        onError: (e) => controller.addError(e),
        onDone: () => controller.close(),
      );

      final file = File(savePath);
      final sink = file.openWrite();
      await controller.stream.pipe(sink);
      await sink.flush();
      await sink.close();

      if (await file.exists()) {
        print("✅ Stream Downloaded: $savePath");
        return file;
      }
      return null;
    } catch (e) {
      print("❌ Download Error: $e");
      final f = File(savePath);
      if (await f.exists()) await f.delete();
      return null;
    }
  }

  // --- UPLOAD ---
  Future<String?> uploadFile(File file, String objectKey) async {
    if (!file.existsSync()) return null;
    try {
      await minio.fPutObject(
        AppConstants.r2BucketName, 
        objectKey, 
        file.path, 
        metadata: {'content-type': 'video/webm'}
      );
      print("✅ R2 Uploaded: $objectKey");
      return objectKey;
    } catch (e) {
      print("❌ Upload Error: $e");
      return null;
    }
  }

  Future<String?> getPresignedUrl(String objectKey) async {
    if (objectKey.isEmpty) return null;
    try {
      return await minio.presignedGetObject(AppConstants.r2BucketName, objectKey, expires: 3600);
    } catch (e) { return null; }
  }

  Future<void> deleteFile(String objectKey, {String? bucketName}) async {
    if (objectKey.isEmpty) return;
    try {
      final targetBucket = bucketName ?? AppConstants.r2BucketName;
      await minio.removeObject(targetBucket, objectKey);
      print("🗑️ Cloud Delete Success: $objectKey from $targetBucket");
    } catch (e) {
      print("❌ Cloud Delete Error: $e");
    }
  }

  // Define receivedBytes here to be safe, though inside the method is fine
  int receivedBytes = 0; 
}