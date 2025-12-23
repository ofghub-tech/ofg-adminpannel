import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'r2_service.dart';
import '../constants.dart';

class DownloadService {
  final R2Service _r2Service = R2Service();

  Future<String> get _workerPath async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'ofg_worker'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<void> prepareWorkspace() async {
    await _workerPath;
  }

  // --- UPDATED: Accepts onProgress callback ---
  Future<File?> downloadVideo(
    String sourceFileId, 
    String title,
    {Function(double)? onProgress} // <--- THIS WAS MISSING
  ) async {
    final workDir = await _workerPath;

    String r2ObjectKey = sourceFileId;
    if (!r2ObjectKey.toLowerCase().endsWith('.mp4')) {
      r2ObjectKey = "$r2ObjectKey.mp4";
    }

    String safeTitle = title.replaceAll(RegExp(r'[^\w\s\.-]'), '').trim();
    if (safeTitle.isEmpty) safeTitle = "video";
    
    String fileName = "${safeTitle}_$sourceFileId.mp4"; 
    String localPath = p.join(workDir, fileName);

    print("⬇️ [DownloadService] Requesting '$r2ObjectKey'...");

    // Pass the onProgress to R2Service
    return await _r2Service.downloadStream(
      r2ObjectKey, 
      localPath, 
      bucketName: AppConstants.r2TempBucketName,
      onProgress: onProgress // <--- Pass it through
    );
  }

  Future<void> openWorkerFolder() async {
    try {
      final path = await _workerPath;
      await Process.run('explorer', [path]);
    } catch (e) {
      print("Could not open folder: $e");
    }
  }

  Future<void> deleteFile(File file) async {
    if (await file.exists()) {
      try {
        await file.delete();
        print("🗑️ Deleted local file: ${file.path}");
      } catch (e) {}
    }
  }
}