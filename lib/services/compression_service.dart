import 'dart:io';
import 'package:path/path.dart' as p;

class QualityProfile {
  final String name;
  final int height;
  final String bitrate;
  final String minRate;
  final String maxRate;

  const QualityProfile(this.name, this.height, this.bitrate, this.minRate, this.maxRate);
}

class CompressionService {
  // Define our 4 target qualities (Matches your Batch File logic)
  static const List<QualityProfile> profiles = [
    QualityProfile('1080p', 1080, '1200k', '600k', '1800k'),
    QualityProfile('720p',  720,  '600k',  '300k', '900k'),
    QualityProfile('480p',  480,  '300k',  '150k', '450k'),
    QualityProfile('360p',  360,  '150k',  '100k', '250k'),
  ];

  Future<String> get _ffmpegPath async {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final prodPath = p.join(exeDir.path, 'data', 'flutter_assets', 'bin', 'svt-vp9', 'ffmpeg.exe');
    if (await File(prodPath).exists()) return prodPath;
    return 'bin/svt-vp9/ffmpeg.exe'; 
  }

  /// The Main Engine - Now accepts callbacks for UI updates
  Future<Map<String, String>> processVideoMultiQuality(
    String inputPath, 
    String outputDir,
    {Function(String)? onStatus, Function(double)? onProgress} // <--- UPDATED
  ) async {
    final ffmpeg = await _ffmpegPath;
    final fileName = p.basenameWithoutExtension(inputPath);
    final results = <String, String>{};

    print('🚀 [Engine] Processing: $fileName');

    // --- STEP 1: AUDIO ---
    if (onStatus != null) onStatus("Extracting Audio...");
    if (onProgress != null) onProgress(0.22); // Jump to 22%

    final audioTemp = p.join(outputDir, 'temp_audio_$fileName.ogg');
    await _runFFmpeg(ffmpeg, [
      '-y', '-v', 'error', '-i', inputPath, '-vn', '-c:a', 'libvorbis', '-q:a', '3', audioTemp
    ]);

    // --- STEP 2: VIDEO LOOP ---
    int totalSteps = profiles.length;
    
    for (var i = 0; i < totalSteps; i++) {
      var profile = profiles[i];
      
      // REPORT STATUS TO UI
      if (onStatus != null) onStatus("Encoding ${profile.name}...");
      
      // REPORT PROGRESS (Compression takes up 25% -> 90% of the bar)
      if (onProgress != null) {
        double base = 0.25;
        double step = 0.65 / totalSteps;
        onProgress(base + (step * i));
      }

      final videoTemp = p.join(outputDir, 'temp_v_${profile.name}_$fileName.webm');
      final finalOutput = p.join(outputDir, '${fileName}_${profile.name}.webm');

      try {
        await _runFFmpeg(ffmpeg, [
          '-y', '-v', 'error', '-stats',
          '-i', inputPath, '-an',
          '-vf', 'scale=-2:${profile.height}',
          '-c:v', 'libvpx-vp9',
          '-b:v', profile.bitrate,
          '-minrate', profile.minRate,
          '-maxrate', profile.maxRate,
          '-crf', '36',
          '-speed', '2',
          videoTemp
        ]);

        // Merge Audio
        if (await File(audioTemp).exists()) {
          await _runFFmpeg(ffmpeg, [
            '-y', '-v', 'error', '-i', videoTemp, '-i', audioTemp,
            '-map', '0:v', '-map', '1:a', '-c', 'copy', finalOutput
          ]);
        } else {
          await File(videoTemp).copy(finalOutput);
        }
        
        results[profile.name] = finalOutput;
      } finally {
        if (await File(videoTemp).exists()) await File(videoTemp).delete();
      }
    }

    if (await File(audioTemp).exists()) await File(audioTemp).delete();
    return results;
  }

  Future<void> _runFFmpeg(String exe, List<String> args) async {
    final result = await Process.run(exe, args);
    if (result.exitCode != 0) throw Exception(result.stderr);
  }
}