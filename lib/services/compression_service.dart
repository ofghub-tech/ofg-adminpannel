import 'dart:async';
import 'dart:convert';
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
  // Production Quality Settings (Balanced for Mobile Streaming)
  static const List<QualityProfile> profiles = [
    QualityProfile('1080p', 1080, '1500k', '750k', '2250k'),
    QualityProfile('720p',  720,  '800k',  '400k', '1200k'),
    QualityProfile('480p',  480,  '400k',  '200k', '600k'),
    QualityProfile('360p',  360,  '200k',  '100k', '300k'),
  ];

  Future<String> _getBinaryPath(String name) async {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final prodPath = p.join(exeDir.path, 'data', 'flutter_assets', 'bin', 'svt-vp9', name);
    if (await File(prodPath).exists()) return prodPath;
    return 'bin/svt-vp9/$name'; 
  }

  // Helper: Get Duration for Progress Calculation
  Future<double> _getVideoDuration(String ffprobe, String inputPath) async {
    try {
      final result = await Process.run(ffprobe, [
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        inputPath
      ]);
      return double.parse(result.stdout.toString().trim());
    } catch (e) {
      return 0.0;
    }
  }

  // Helper: Parse FFmpeg time to seconds
  double _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      double h = double.parse(parts[0]);
      double m = double.parse(parts[1]);
      double s = double.parse(parts[2]);
      return (h * 3600) + (m * 60) + s;
    } catch (e) {
      return 0.0;
    }
  }

  Future<Map<String, String>> processVideoMultiQuality(
    String inputPath, 
    String outputDir,
    {Function(String)? onStatus, Function(double)? onProgress}
  ) async {
    final ffmpeg = await _getBinaryPath('ffmpeg.exe');
    final ffprobe = await _getBinaryPath('ffprobe.exe');
    final fileName = p.basenameWithoutExtension(inputPath);
    final results = <String, String>{};

    if (onStatus != null) onStatus("Initializing Engine...");
    final totalDuration = await _getVideoDuration(ffprobe, inputPath);

    // --- STEP 1: EXTRACT AUDIO ---
    if (onStatus != null) onStatus("Extracting Audio...");
    if (onProgress != null) onProgress(0.05);

    final audioTemp = p.join(outputDir, 'temp_audio_$fileName.ogg');
    await _runSimple(ffmpeg, [
      '-y', '-v', 'error', 
      '-i', inputPath, 
      '-vn', '-c:a', 'libvorbis', '-q:a', '3', 
      audioTemp
    ]);

    // --- STEP 2: VIDEO COMPRESSION LOOP ---
    int totalSteps = profiles.length;
    
    for (var i = 0; i < totalSteps; i++) {
      var profile = profiles[i];
      if (onStatus != null) onStatus("Encoding ${profile.name}...");
      
      // Calculate progress segment
      double startP = 0.05 + ((0.90 / totalSteps) * i);
      double endP = 0.05 + ((0.90 / totalSteps) * (i + 1));

      final videoTemp = p.join(outputDir, 'temp_v_${profile.name}_$fileName.webm');
      final finalOutput = p.join(outputDir, '${fileName}_${profile.name}.webm');

      try {
        await _runWithProgress(
          ffmpeg, 
          [
            '-y', '-v', 'info', '-stats',
            '-i', inputPath,
            '-an', 
            '-vf', 'scale=-2:${profile.height}',
            '-c:v', 'libvpx-vp9',
            '-b:v', profile.bitrate,
            '-minrate', profile.minRate,
            '-maxrate', profile.maxRate,
            '-crf', '36',
            '-speed', '2',
            '-threads', '8', '-row-mt', '1', '-tile-columns', '2',
            videoTemp
          ],
          totalDuration,
          (val) {
            if (onProgress != null) onProgress(startP + (val * (endP - startP)));
          }
        );

        // --- STEP 3: MERGE ---
        List<String> muxArgs = ['-y', '-v', 'error', '-i', videoTemp];
        if (await File(audioTemp).exists()) {
          muxArgs.addAll(['-i', audioTemp, '-c', 'copy', finalOutput]);
        } else {
          muxArgs.addAll(['-c', 'copy', finalOutput]);
        }
        await _runSimple(ffmpeg, muxArgs);
        
        results[profile.name] = finalOutput;

      } catch (e) {
        print("❌ Error ${profile.name}: $e");
      } finally {
        if (await File(videoTemp).exists()) await File(videoTemp).delete();
      }
    }

    if (await File(audioTemp).exists()) await File(audioTemp).delete();
    if (onProgress != null) onProgress(1.0);
    
    return results;
  }

  Future<void> _runSimple(String exe, List<String> args) async {
    final result = await Process.run(exe, args);
    if (result.exitCode != 0) throw Exception(result.stderr);
  }

  Future<void> _runWithProgress(String exe, List<String> args, double duration, Function(double) onP) async {
    final process = await Process.start(exe, args);
    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.contains('time=')) {
        final match = RegExp(r'time=(\d{2}:\d{2}:\d{2}\.\d{2})').firstMatch(line);
        if (match != null && duration > 0) {
          onP(_parseTime(match.group(1)!) / duration);
        }
      }
    });
    if (await process.exitCode != 0) throw Exception("FFmpeg failed");
  }
}