// lib/screens/admin_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../services/appwrite_service.dart';
import '../services/r2_service.dart';
import '../services/compression_service.dart';
import '../services/download_service.dart';
import '../widgets/video_card.dart';
import 'login_screen.dart';
import 'player_screen.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AppwriteService _dbService = AppwriteService();
  final R2Service _r2Service = R2Service();
  final DownloadService _downloadService = DownloadService();
  
  final String _r2PublicDomain = "https://pub-xxxxxxxxxxxx.r2.dev"; 

  bool _isProcessingBatch = false;
  bool _isLoading = true;
  List<VideoModel> _videos = [];
  
  final ValueNotifier<double> _progressValue = ValueNotifier(0.0);
  final ValueNotifier<String> _progressLabel = ValueNotifier("Initializing...");

  @override
  void initState() {
    super.initState();
    _loadData();
    _downloadService.prepareWorkspace();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    List<VideoModel> data = await _dbService.getVideos();
    if (mounted) setState(() { _videos = data; _isLoading = false; });
  }

  // --- APPROVED LOGIC: Directly sets to 'approved' ---
  Future<void> _handleApprove(VideoModel video) async {
    await _dbService.updateStatus(video.id, {
      'adminStatus': 'approved'
    });
    _loadData();
  }

  // --- COMPRESSION ENGINE: Uploads variants, updates DB, deletes temp ---
  Future<void> _triggerCompression(List<VideoModel> videos) async {
    if (videos.isEmpty || _isProcessingBatch) return;

    setState(() { _isProcessingBatch = true; });
    _showProgressDialog(context);
    final compressionService = CompressionService();

    try {
      for (var video in videos) {
        File? localRawFile;
        Map<String, String> localOutputs = {};
        
        try {
          _progressLabel.value = "⬇️ Downloading ${video.title}...";
          localRawFile = await _downloadService.downloadVideo(
            video.sourceFileId, video.title,
            onProgress: (p) => _progressValue.value = p * 0.15 
          );
          
          if (localRawFile == null) throw Exception("Download Failed");

          _progressLabel.value = "⚙️ Encoding Multi-Quality...";
          localOutputs = await compressionService.processVideoMultiQuality(
            localRawFile.path, localRawFile.parent.path,
            onProgress: (p) => _progressValue.value = 0.15 + (p * 0.60)
          );

          _progressLabel.value = "☁️ Uploading to Storage...";
          Map<String, dynamic> dbUpdates = {
            'compressionStatus': 'done',
            'videoUrl': null, // Clear raw link in DB
          };

          for (var entry in localOutputs.entries) {
            String quality = entry.key; 
            File file = File(entry.value);
            String remoteName = "${video.id}_$quality.webm";

            await _r2Service.uploadFile(file, remoteName);
            dbUpdates['url_$quality'] = "$_r2PublicDomain/$remoteName";
          }

          // Update Appwrite Backend
          bool updated = await _dbService.updateStatus(video.id, dbUpdates);
          if (!updated) throw Exception("DB Update Failed");

          // Delete Temp Cloud File
          if (video.sourceFileId.isNotEmpty) {
             await _r2Service.deleteFile(video.sourceFileId); 
          }

          _showSnack("✅ Compression Success: ${video.title}", Colors.green);

        } catch (e) {
          print("Error: $e");
        } finally {
           // Cleanup local workspace
           if (localRawFile != null && await localRawFile.exists()) await localRawFile.delete();
           for (var path in localOutputs.values) {
             if (await File(path).exists()) await File(path).delete();
           }
        }
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); 
        setState(() { _isProcessingBatch = false; });
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var inboxList = _videos.where((v) => v.adminStatus == 'pending').toList();
    // Videos in "Compression" tab are approved videos that aren't compressed yet
    var compressionList = _videos.where((v) => v.adminStatus == 'approved' && v.compressionStatus == 'waiting').toList();
    // "Review" tab can show already compressed videos
    var reviewList = _videos.where((v) => v.adminStatus == 'approved' && v.compressionStatus == 'done').toList();

    int selectedCount = compressionList.where((v) => v.isSelected).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Admin Dashboard"),
          bottom: TabBar(
            tabs: [
              Tab(text: "Inbox (${inboxList.length})"),
              Tab(text: "Compression (${compressionList.length})"),
              Tab(text: "Review (${reviewList.length})"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(inboxList, isSelectionMode: false),
            _buildList(compressionList, isSelectionMode: true),
            _buildList(reviewList, isSelectionMode: false),
          ],
        ),
        floatingActionButton: (selectedCount > 0)
          ? FloatingActionButton.extended(
              backgroundColor: Colors.blue[800],
              icon: Icon(Icons.cloud_upload, color: Colors.white),
              label: Text("Compress $selectedCount Videos"),
              onPressed: () => _triggerCompression(compressionList.where((v) => v.isSelected).toList()),
            )
          : null,
      ),
    );
  }

  Widget _buildList(List<VideoModel> list, {required bool isSelectionMode}) {
    if (_isLoading) return Center(child: CircularProgressIndicator());
    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final video = list[i];
        return VideoCard(
          video: video,
          showActions: true,
          isSelectionMode: isSelectionMode,
          onSelectionChanged: isSelectionMode ? (val) => setState(() => video.isSelected = val!) : null,
          onPlay: () => _handlePlay(video),
          onApprove: () => _handleApprove(video),
          onDelete: () => _handleDelete(video),
        );
      },
    );
  }

  // --- UI Helpers ---
  void _showProgressDialog(BuildContext context) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
      content: Container(height: 100, width: 300, child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ValueListenableBuilder<String>(valueListenable: _progressLabel, builder: (_, val, __) => Text(val)),
          SizedBox(height: 15),
          ValueListenableBuilder<double>(valueListenable: _progressValue, builder: (_, val, __) => LinearProgressIndicator(value: val > 0 ? val : null)),
        ],
      )),
    ));
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _handleDelete(VideoModel video) async {
    if (await _dbService.deleteDocument(video.id)) _loadData();
  }

  Future<void> _handlePlay(VideoModel video) async {
    String? playUrl = video.url720p ?? video.videoUrl;
    if (playUrl != null) Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(videoUrl: playUrl, title: video.title)));
  }
}