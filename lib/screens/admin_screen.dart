import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart'; 
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  
  // ⚠️ IMPORTANT: REPLACE WITH YOUR REAL R2 PUBLIC DOMAIN
  // Example: https://pub-123456789.r2.dev
  final String _r2PublicDomain = "https://pub-xxxxxxxxxxxx.r2.dev"; 

  bool _isProcessingBatch = false;
  bool _isLoading = true;
  List<VideoModel> _videos = [];
  
  // Progress UI Variables
  final ValueNotifier<double> _progressValue = ValueNotifier(0.0);
  final ValueNotifier<String> _progressLabel = ValueNotifier("Initializing...");

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    _loadData();
    _downloadService.prepareWorkspace();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    // Fetch ALL videos (we will filter them by tab locally)
    List<VideoModel> data = await _dbService.getVideos(); 
    if (mounted) setState(() { _videos = data; _isLoading = false; });
  }

  // --- ACTIONS (Approve, Delete, Play) ---

  Future<void> _handleApprove(VideoModel video) async {
    // Logic: Pending -> Reviewed -> Approved
    String nextStatus = video.adminStatus.toLowerCase() == 'pending' ? 'reviewed' : 'approved';
    
    await _dbService.updateStatus(video.id, {
      'adminStatus': nextStatus
    });
    _loadData();
  }

  Future<void> _handleDelete(VideoModel video) async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Delete '${video.title}'?"),
      content: Text("This will permanently remove the video."),
      actions: [
        TextButton(onPressed:()=>Navigator.pop(c,false),child:Text("Cancel")),
        TextButton(onPressed:()=>Navigator.pop(c,true),child:Text("Delete", style: TextStyle(color:Colors.red))),
      ],
    )) ?? false;
    
    if (!confirm) return;

    if (await _dbService.deleteDocument(video.id)) {
      // 1. Try to delete Raw File
      if (video.sourceFileId.isNotEmpty) {
        try { await _r2Service.deleteFile(video.sourceFileId); } catch(e) { print("R2 Delete Error: $e"); }
      }
      // 2. Try to delete Compressed Files (if they exist)
      List<String> qualities = ['1080p', '720p', '480p', '360p'];
      for (var q in qualities) {
         try { await _r2Service.deleteFile("${video.id}_$q.webm"); } catch (_) {}
      }
      _loadData();
    }
  }

  Future<void> _handlePlay(VideoModel video) async {
    String playUrl = "";

    // 1. Try playing the 720p version (Best for preview)
    if (video.url720p != null && video.url720p!.isNotEmpty) {
      playUrl = video.url720p!;
    }
    // 2. Fallback: Try the old/main videoUrl
    else if (video.videoUrl != null && video.videoUrl!.isNotEmpty) {
      playUrl = video.videoUrl!;
    } 
    // 3. Last Resort: Play Raw File (Needs Presigned URL because it is likely private)
    else if (video.sourceFileId.isNotEmpty) {
       _showSnack("⏳ Fetching raw preview...", Colors.blue);
       
       // FIXED: Added '?? ""' to handle nulls
       playUrl = await _r2Service.getPresignedUrl(video.sourceFileId) ?? "";
    }

    if (playUrl.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
        videoUrl: playUrl, 
        title: video.title
      )));
    } else {
      _showSnack("❌ No playable URL found.", Colors.red);
    }
  }

  // --- 🚀 PRODUCTION COMPRESSION ENGINE ---
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
          // --- STEP 1: DOWNLOAD ---
          _progressLabel.value = "⬇️ Downloading ${video.title}...";
          _progressValue.value = 0.0;
          
          localRawFile = await _downloadService.downloadVideo(
            video.sourceFileId, 
            video.title,
            onProgress: (p) => _progressValue.value = p * 0.15 
          );
          
          if (localRawFile == null) throw Exception("Download Failed");

          // --- STEP 2: COMPRESS ---
          _progressLabel.value = "⚙️ Encoding (VP9 Multi-Thread)...";
          localOutputs = await compressionService.processVideoMultiQuality(
            localRawFile.path, 
            localRawFile.parent.path,
            onStatus: (msg) => _progressLabel.value = msg,
            onProgress: (p) => _progressValue.value = 0.15 + (p * 0.60)
          );

          // --- STEP 3: UPLOAD & PREPARE DB UPDATE ---
          _progressLabel.value = "☁️ Uploading Variants...";
          
          Map<String, dynamic> dbUpdates = {
            'adminStatus': 'approved', 
            'compressionStatus': 'done', // Ensure this column exists in Appwrite!
            'videoUrl': null, // Clear the old raw link
          };

          int count = 0;
          for (var entry in localOutputs.entries) {
            String quality = entry.key; 
            File file = File(entry.value);
            String remoteName = "${video.id}_$quality.webm";

            await _r2Service.uploadFile(file, remoteName);
            
            // Construct Public URL
            String publicUrl = "$_r2PublicDomain/$remoteName";
            
            if (quality == '1080p') dbUpdates['url_1080p'] = publicUrl;
            if (quality == '720p') dbUpdates['url_720p'] = publicUrl;
            if (quality == '480p') dbUpdates['url_480p'] = publicUrl;
            if (quality == '360p') dbUpdates['url_360p'] = publicUrl;

            count++;
            _progressValue.value = 0.75 + ((0.20 / localOutputs.length) * count);
          }

          // --- STEP 4: UPDATE DB (With Safety Check) ---
          _progressLabel.value = "📝 Updating Database...";
          
          bool updated = await _dbService.updateStatus(video.id, dbUpdates);
          
          if (!updated) {
            throw Exception("Database Update Failed! Check Appwrite attributes (compressionStatus, url_1080p, etc).");
          }

          // --- STEP 5: DELETE RAW (Only if DB update succeeded) ---
          _progressLabel.value = "🗑️ Deleting Cloud Raw File...";
          if (video.sourceFileId.isNotEmpty) {
             await _r2Service.deleteFile(video.sourceFileId); 
          }

          _showSnack("✅ Live: ${video.title}", Colors.green);

        } catch (e) {
          print("Error: $e");
          _progressLabel.value = "❌ Error: $e";
          // Pause so you can read the error
          await Future.delayed(Duration(seconds: 6));
        } finally {
           // --- STEP 6: CLEANUP LOCAL ---
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
        _loadData(); // Refresh UI to show new status
      }
    }
  }

  void _showProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Container(
            height: 100,
            width: 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: _progressLabel,
                  builder: (_, val, __) => Text(val, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: 15),
                ValueListenableBuilder<double>(
                  valueListenable: _progressValue,
                  builder: (_, val, __) => LinearProgressIndicator(
                    value: val > 0 ? val : null, 
                    backgroundColor: Colors.grey[200],
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    // Filter Lists for Tabs
    var inboxList = _videos.where((v) => v.adminStatus.toLowerCase() == 'pending').toList();
    var reviewList = _videos.where((v) => v.adminStatus.toLowerCase() == 'reviewed').toList();
    var libraryList = _videos.where((v) => v.adminStatus.toLowerCase() == 'approved').toList();

    // Count selected items in Review tab
    int selectedCount = reviewList.where((v) => v.isSelected).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Admin Dashboard"),
          actions: [
            IconButton(icon: Icon(Icons.refresh), onPressed: _loadData),
            IconButton(icon: Icon(Icons.logout), onPressed: () async {
              await _dbService.logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            }),
          ],
          bottom: TabBar(
            labelColor: Colors.blue[800],
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Inbox (${inboxList.length})"),
              Tab(text: "Review (${reviewList.length})"),
              Tab(text: "Library"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: INBOX (Action: Approve to move to Review)
            _buildList(inboxList, isReviewTab: false),
            
            // TAB 2: REVIEW (Action: Select & Publish)
            _buildList(reviewList, isReviewTab: true),
            
            // TAB 3: LIBRARY (Read Only / Delete)
            _buildList(libraryList, isReviewTab: false),
          ],
        ),
        floatingActionButton: (selectedCount > 0)
          ? FloatingActionButton.extended(
              backgroundColor: Colors.blue[800],
              icon: Icon(Icons.cloud_upload, color: Colors.white),
              label: Text("Publish $selectedCount Videos", style: TextStyle(color: Colors.white)),
              onPressed: _isProcessingBatch 
                  ? null 
                  : () => _triggerCompression(reviewList.where((v) => v.isSelected).toList()),
            )
          : null,
      ),
    );
  }

  Widget _buildList(List<VideoModel> list, {required bool isReviewTab}) {
    if (_isLoading) return Center(child: CircularProgressIndicator());
    if (list.isEmpty) return Center(child: Text("No videos found", style: TextStyle(color: Colors.grey)));

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_,__) => SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final video = list[i];
        return VideoCard(
          video: video,
          showActions: true,
          // Only allow Selection Mode in the "Review" tab
          isSelectionMode: isReviewTab, 
          onSelectionChanged: isReviewTab 
              ? (val) => setState(() => video.isSelected = val!) 
              : null,
          onPlay: () => _handlePlay(video),
          onApprove: () => _handleApprove(video),
          onDelete: () => _handleDelete(video),
        );
      },
    );
  }
}