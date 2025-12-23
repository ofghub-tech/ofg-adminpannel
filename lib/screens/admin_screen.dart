import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:async'; 
import 'package:appwrite/appwrite.dart'; // Needed for RealtimeSubscription

import '../models/video_model.dart';
import '../services/appwrite_service.dart';
import '../services/r2_service.dart';
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
  final TextEditingController _searchController = TextEditingController();
  
  Timer? _debounce;
  RealtimeSubscription? _subscription; // <--- NEW: To hold connection
  
  List<VideoModel> _videos = [];
  bool _isLoading = true;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToRealtime(); // <--- NEW: Start listening
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.close(); // <--- NEW: Clean up connection
    _searchController.dispose();
    super.dispose();
  }

  // --- REALTIME NOTIFICATIONS ---
  void _subscribeToRealtime() {
    try {
      _subscription = _dbService.subscribeToVideos();
      _subscription!.stream.listen((event) {
        // Check if the event is a "create" event (new upload)
        if (event.events.any((e) => e.endsWith('.create'))) {
          print("Realtime: New video detected!");
          
          if (mounted) {
            // 1. Show Notification
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.video_library, color: Colors.white),
                    SizedBox(width: 12),
                    Text("New video uploaded! List updated."),
                  ],
                ),
                backgroundColor: Color(0xFF0F172A),
                duration: Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              )
            );

            // 2. Auto-Refresh Data
            _loadData();
          }
        }
      });
    } catch (e) {
      print("Realtime Error: $e");
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData(searchTerm: _searchController.text);
    });
  }

  Future<void> _loadData({String? searchTerm}) async {
    // Only show loading spinner on initial load to avoid flickering on auto-refresh
    if (_videos.isEmpty) setState(() => _isLoading = true);
    
    List<VideoModel> data = await _dbService.getVideos(searchTerm: searchTerm);
    
    if (mounted) {
      setState(() {
        _videos = data;
        _isLoading = false;
      });
    }
  }

  // ... [Keep _handleEmail, _handleDelete, _handleApprove, _handlePlay methods exactly as before] ...
  Future<void> _handleEmail(VideoModel video) async {
    if (video.email.isEmpty) {
      _showSnack("No email address found for this user", Colors.orange);
      return;
    }
    final String subject = "Regarding your video submission: ${video.title}";
    final String body = "Hello ${video.username},\n\nWe are reviewing your video titled '${video.title}'.\n\nRegards,\nAdmin Team";
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: video.email,
      query: _encodeQueryParameters({'subject': subject, 'body': body}),
    );
    try { await launchUrl(emailUri); } catch (e) { _showSnack("Could not launch email client: $e", Colors.red); }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
  }

  Future<void> _handleDelete(VideoModel video) async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Delete '${video.title}'?"),
      content: Text("This will permanently remove the video record and files."),
      actions: [
        TextButton(onPressed:()=>Navigator.pop(c,false),child:Text("Cancel")),
        TextButton(onPressed:()=>Navigator.pop(c,true),child:Text("Delete Forever", style: TextStyle(color:Colors.red))),
      ],
    )) ?? false;
    
    if (!confirm) return;

    setState(() => _isLoading = true);
    bool dbSuccess = await _dbService.deleteDocument(video.id);
    
    if (dbSuccess) {
      if (video.sourceFileId.isNotEmpty) await _r2Service.deleteFile(video.sourceFileId);
      _showSnack("Deleted successfully", Colors.black87);
      _loadData();
    } else {
      setState(() => _isLoading = false);
      _showSnack("Failed to delete video record", Colors.red);
    }
  }

  Future<void> _handleApprove(VideoModel video) async {
    String currentStatus = video.adminStatus.toLowerCase();
    String nextStatus = (currentStatus == 'pending') ? 'reviewed' : 'approved';
    bool success = await _dbService.updateStatus(video.id, {'adminStatus': nextStatus});
    if (success) {
      _showSnack("Status updated to $nextStatus", Colors.black87);
      _loadData();
    } else {
      _showSnack("Update failed", Colors.red);
    }
  }
  // ... [End of existing methods] ...

  @override
  Widget build(BuildContext context) {
    var pendingList = _videos.where((v) => v.adminStatus.toLowerCase() == 'pending').toList();
    var reviewedList = _videos.where((v) => v.adminStatus.toLowerCase() == 'reviewed').toList();
    var approvedList = _videos.where((v) => v.adminStatus.toLowerCase() == 'approved').toList();
    
    int selectedCount = approvedList.where((v) => v.isSelected).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Connects Admin"),
          actions: [
            IconButton(icon: Icon(Icons.refresh), onPressed: () => _loadData()),
            IconButton(icon: Icon(Icons.logout), onPressed: () async {
              await _dbService.logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            }),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(110),
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search server for title...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _isLoading ? Container(width: 12, height: 12, margin: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                        filled: true,
                        fillColor: Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  TabBar(
                    labelColor: Color(0xFF0F172A),
                    unselectedLabelColor: Color(0xFF94A3B8),
                    indicatorColor: Color(0xFF3B82F6),
                    tabs: [
                      Tab(text: "Inbox (${pendingList.length})"),
                      Tab(text: "Review (${reviewedList.length})"),
                      Tab(text: "Library (${approvedList.length})"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(pendingList, showActions: true),
            _buildList(reviewedList, showActions: true),
            _buildList(approvedList, showActions: false, isLibrary: true),
          ],
        ),
        floatingActionButton: (_isDesktop && selectedCount > 0)
          ? FloatingActionButton.extended(
              backgroundColor: Color(0xFF0F172A),
              icon: Icon(Icons.compress, color: Colors.white),
              label: Text("Compress $selectedCount", style: TextStyle(color: Colors.white)),
              onPressed: () => _triggerCompression(approvedList.where((v) => v.isSelected).toList()),
            )
          : null,
      ),
    );
  }

  Widget _buildList(List<VideoModel> list, {required bool showActions, bool isLibrary = false}) {
    // FIX: Always return a RefreshIndicator, even if empty, so you can pull to refresh even on empty screens
    Widget content;
    if (list.isEmpty) {
      content = Center(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works on empty list
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            child: Text(_isLoading ? "Loading..." : "No videos found", style: TextStyle(color: Colors.grey[500])),
          ),
        ),
      );
    } else {
      content = ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (ctx, i) => SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final video = list[i];
          bool showCheckbox = _isDesktop && isLibrary;
          bool canSelect = video.compressionStatus.toLowerCase() == 'waiting';

          return VideoCard(
            video: video,
            showActions: showActions,
            isSelectionMode: showCheckbox,
            onSelectionChanged: canSelect ? (val) => setState(() => video.isSelected = val!) : null,
            onApprove: () => _handleApprove(video),
            onDelete: () => _handleDelete(video),
            onEmail: () => _handleEmail(video),
            onPlay: () => _handlePlay(video),
          );
        },
      );
    }

    // <--- NEW: Pull to Refresh Wrapper
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData(searchTerm: _searchController.text);
      },
      child: content,
    );
  }

  // --- UTILS ---
  Future<void> _handlePlay(VideoModel video) async {
    String? playUrl = video.videoUrl.isNotEmpty 
        ? video.videoUrl 
        : await _r2Service.getPresignedUrl(video.sourceFileId);

    if (playUrl != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(videoUrl: playUrl, title: video.title)));
    } else {
      _showSnack("No playable URL found", Colors.red);
    }
  }

  Future<void> _triggerCompression(List<VideoModel> videos) async {
    var futures = videos.map((v) => _dbService.updateStatus(v.id, {'compressionStatus': 'queued'}));
    await Future.wait(futures);
    _showSnack("Queued ${videos.length} videos", Colors.blueAccent);
    setState(() { for (var v in videos) v.isSelected = false; });
    _loadData();
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }
}