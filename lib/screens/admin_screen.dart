import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:appwrite/appwrite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/video_model.dart';
import '../services/appwrite_service.dart';
import '../services/r2_service.dart';
import '../services/compression_service.dart';
import '../services/download_service.dart';
import '../widgets/video_card.dart';
import '../constants.dart';
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
  final TextEditingController _searchController = TextEditingController();
  
  Timer? _debounce;
  RealtimeSubscription? _subscription;
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  bool _isProcessingBatch = false;

  final ValueNotifier<double> _progressValue = ValueNotifier(0.0);
  final ValueNotifier<String> _progressLabel = ValueNotifier("Initializing...");

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    // _subscribeToRealtime(); // Disabled
    _searchController.addListener(_onSearchChanged);
    _downloadService.prepareWorkspace();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.close();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData(searchTerm: _searchController.text);
    });
  }

  Future<void> _loadData({String? searchTerm}) async {
    if (_videos.isEmpty) setState(() => _isLoading = true);
    List<VideoModel> data = await _dbService.getVideos(searchTerm: searchTerm);
    if (mounted) setState(() { _videos = data; _isLoading = false; });
  }

  Future<void> _handleApprove(VideoModel video) async {
    String nextStatus = video.adminStatus.toLowerCase() == 'pending' ? 'reviewed' : 'approved';
    await _dbService.updateStatus(video.id, {'adminStatus': nextStatus});
    _loadData();
  }

  Future<void> _handleDelete(VideoModel video) async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Delete '${video.title}'?"),
      actions: [
        TextButton(onPressed:()=>Navigator.pop(c,false),child:Text("Cancel")),
        TextButton(onPressed:()=>Navigator.pop(c,true),child:Text("Delete", style: TextStyle(color:Colors.red))),
      ],
    )) ?? false;
    
    if (!confirm) return;
    if (await _dbService.deleteDocument(video.id)) {
      if (video.sourceFileId.isNotEmpty) await _r2Service.deleteFile(video.sourceFileId);
      _loadData();
    }
  }

  Future<void> _handlePlay(VideoModel video) async {
    // UPDATED PLAY LOGIC: Priority to compressed URLs
    String? playUrl = video.videoUrl;
    
    // Fallback: Presigned URL of best guess compressed
    if ((playUrl == null || playUrl.isEmpty) && video.id.isNotEmpty) {
       // Try 720p guess
       String guess720 = "${video.id}_720p.webm";
       playUrl = await _r2Service.getPresignedUrl(guess720);
    }
    
    // Fallback: Source File
    if (playUrl == null || playUrl.isEmpty) {
       playUrl = await _r2Service.getPresignedUrl(video.sourceFileId);
    }

    if (playUrl != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(videoUrl: playUrl!, title: video.title)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No playable URL found")));
    }
  }

  void _showProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 3),
                SizedBox(width: 15),
                Text("Processing", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Container(
              height: 80,
              width: 350,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: _progressLabel,
                    builder: (context, value, _) => Text(
                      value, 
                      style: TextStyle(fontSize: 15, color: Colors.blueGrey[800], fontWeight: FontWeight.w500)
                    ),
                  ),
                  SizedBox(height: 12),
                  ValueListenableBuilder<double>(
                    valueListenable: _progressValue,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value > 0 ? value : null,
                      backgroundColor: Colors.grey[200],
                      color: Colors.blue[700],
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- COMPRESSION PIPELINE ---
  Future<void> _triggerCompression(List<VideoModel> videos) async {
    if (videos.isEmpty || _isProcessingBatch) return;

    _isProcessingBatch = true;
    _showProgressDialog(context);

    final compressionService = CompressionService();

    try {
      for (var video in videos) {
        File? localRawFile;
        Map<String, String> localOutputs = {};
        
        String r2RawKey = video.sourceFileId;
        if (!r2RawKey.toLowerCase().endsWith('.mp4')) r2RawKey += ".mp4";

        try {
          // --- STEP 1: DOWNLOAD ---
          _progressLabel.value = "Starting download...";
          _progressValue.value = 0.0;
          await _dbService.updateStatus(video.id, {'compressionStatus': 'processing'});

          localRawFile = await _downloadService.downloadVideo(
            video.sourceFileId, 
            video.title,
            onProgress: (p) { 
               _progressLabel.value = "Downloading: ${(p * 100).toInt()}%";
               _progressValue.value = p * 0.20; 
            }
          );
          
          if (localRawFile == null) throw Exception("Download Failed");

          // --- STEP 2: COMPRESS ---
          String workDir = localRawFile.parent.path;
          localOutputs = await compressionService.processVideoMultiQuality(
            localRawFile.path, 
            workDir,
            onStatus: (msg) => _progressLabel.value = msg,
            onProgress: (val) => _progressValue.value = val
          );
          
          // --- STEP 3: UPLOAD ---
          _progressLabel.value = "Uploading versions...";
          _progressValue.value = 0.90; 
          
          Map<String, dynamic> updates = {'compressionStatus': 'done'};
          int uploadCount = 0;
          int totalUploads = localOutputs.length;

          for (var entry in localOutputs.entries) {
             String quality = entry.key;
             File f = File(entry.value);
             String uploadKey = "${video.id}_$quality.webm";

             _progressLabel.value = "Uploading $quality...";
             
             if (await _r2Service.uploadFile(f, uploadKey) != null) {
               updates['url_$quality'] = uploadKey;
             }
             
             uploadCount++;
             _progressValue.value = 0.90 + ((uploadCount / totalUploads) * 0.10);
          }

          // FIX: Use 'video_url' (snake_case) to match your database column!
          if (updates.containsKey('url_720p')) {
            updates['video_url'] = updates['url_720p'];
          } else if (updates.containsKey('url_480p')) {
            updates['video_url'] = updates['url_480p'];
          }

          // --- STEP 4: UPDATE DB ---
          _progressLabel.value = "Updating Database...";
          // This will now SUCCEED because the key name is correct
          await _dbService.updateStatus(video.id, updates);

          // --- STEP 5: DELETE RAW FROM TEMP BUCKET ---
          // This runs only if the DB update above succeeds
          _progressLabel.value = "Deleting Temp File from Cloud...";
          await _r2Service.deleteFile(
            r2RawKey, 
            bucketName: AppConstants.r2TempBucketName
          );

          _showSnack("✅ Success: ${video.title}", Colors.green);

        } catch (e) {
          print("Error: $e");
          _progressLabel.value = "Error: $e";
          await Future.delayed(Duration(seconds: 4));
          // If error, mark as error so you know to retry
          await _dbService.updateStatus(video.id, {'compressionStatus': 'error'});
        } finally {
           _progressLabel.value = "Cleaning local files...";
           if (localRawFile != null) await _downloadService.deleteFile(localRawFile);
           for (var path in localOutputs.values) {
             await _downloadService.deleteFile(File(path));
           }
        }
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); 
        _isProcessingBatch = false;
        setState(() { for (var v in videos) v.isSelected = false; });
        _loadData();
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    var approvedList = _videos.where((v) => v.adminStatus.toLowerCase() == 'approved').toList();
    int selectedCount = approvedList.where((v) => v.isSelected).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("OFG Connector"),
          actions: [
            if (_isDesktop)
              IconButton(
                tooltip: "Open Temp Folder",
                icon: Icon(Icons.folder_open),
                onPressed: () => _downloadService.openWorkerFolder(),
              ),
            IconButton(icon: Icon(Icons.refresh), onPressed: () => _loadData()),
            IconButton(icon: Icon(Icons.logout), onPressed: () async {
              await _dbService.logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            }),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(50),
            child: TabBar(
              labelColor: Colors.black,
              tabs: [
                Tab(text: "Inbox"),
                Tab(text: "Review"),
                Tab(text: "Library"), 
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(_videos.where((v) => v.adminStatus == 'pending').toList(), true),
            _buildList(_videos.where((v) => v.adminStatus == 'reviewed').toList(), true),
            _buildList(approvedList, false, isLibrary: true),
          ],
        ),
        floatingActionButton: (_isDesktop && selectedCount > 0)
          ? FloatingActionButton.extended(
              backgroundColor: Color(0xFF0F172A),
              icon: Icon(Icons.compress, color: Colors.white),
              label: Text("Compress $selectedCount", style: TextStyle(color: Colors.white)),
              onPressed: _isProcessingBatch 
                  ? null 
                  : () => _triggerCompression(approvedList.where((v) => v.isSelected).toList()),
            )
          : null,
      ),
    );
  }

  Widget _buildList(List<VideoModel> list, bool showActions, {bool isLibrary = false}) {
    if (list.isEmpty) return Center(child: Text("No videos"));
    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_,__) => SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final video = list[i];
        bool showCheckbox = _isDesktop && isLibrary;
        return VideoCard(
          video: video,
          showActions: showActions,
          isSelectionMode: showCheckbox,
          onSelectionChanged: showCheckbox ? (val) => setState(() => video.isSelected = val!) : null,
          onApprove: () => _handleApprove(video),
          onDelete: () => _handleDelete(video),
          onPlay: () => _handlePlay(video),
        );
      },
    );
  }
}