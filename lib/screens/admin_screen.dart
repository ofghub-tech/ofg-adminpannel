import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  
  List<VideoModel> _allVideos = [];
  List<VideoModel> _filteredVideos = [];
  bool _isLoading = true;
  String _searchQuery = "";

  // PLATFORM CHECK
  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterData();
      });
    });
  }

  void _filterData() {
    if (_searchQuery.isEmpty) {
      _filteredVideos = List.from(_allVideos);
    } else {
      _filteredVideos = _allVideos.where((v) {
        return v.title.toLowerCase().contains(_searchQuery) || 
               v.username.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadData() async {
    if(_allVideos.isEmpty) setState(() => _isLoading = true);
    List<VideoModel> data = await _dbService.getVideos();
    if (mounted) {
      setState(() {
        _allVideos = data;
        _filterData();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await _dbService.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
    }
  }

  Future<void> _handlePlay(VideoModel video) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (c) => Center(child: CircularProgressIndicator())
    );

    String? playUrl;

    // FIX: Check for Direct URL first (New Logic)
    if (video.videoUrl.isNotEmpty) {
      playUrl = video.videoUrl;
      print("Playing via Direct URL: $playUrl");
    } 
    // Fallback to R2 Presigned URL (Old Logic)
    else if (video.sourceFileId.isNotEmpty) {
      playUrl = await _r2Service.getPresignedUrl(video.sourceFileId);
      print("Playing via R2 Generated URL: $playUrl");
    }

    if (mounted) Navigator.pop(context);

    if (playUrl != null && playUrl.isNotEmpty && mounted) {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (_) => PlayerScreen(videoUrl: playUrl!, title: video.title)
        )
      );
    } else if (mounted) {
      _showSnack("No playable URL found", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    var pendingList = _filteredVideos.where((v) => v.adminStatus.toLowerCase() == 'pending').toList();
    var reviewedList = _filteredVideos.where((v) => v.adminStatus.toLowerCase() == 'reviewed').toList();
    var approvedList = _filteredVideos.where((v) => v.adminStatus.toLowerCase() == 'approved').toList();
    
    int selectedCount = approvedList.where((v) => v.isSelected).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Connects Admin"),
          actions: [
            IconButton(icon: Icon(Icons.refresh), onPressed: _loadData),
            IconButton(icon: Icon(Icons.logout), onPressed: _handleLogout),
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
                        hintText: "Search title or user...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
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
        body: _isLoading 
            ? Center(child: CircularProgressIndicator()) 
            : TabBarView(
                children: [
                  _buildList(pendingList, showActions: true),
                  _buildList(reviewedList, showActions: true),
                  _buildList(approvedList, showActions: false, isLibrary: true),
                ],
              ),
        
        // Show Compress button ONLY if Desktop AND items selected
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
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text("No videos here", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (ctx, i) => SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final video = list[i];
        
        // Logic: Show Checkbox ONLY if Desktop + Library Tab + Waiting status
        bool showCheckbox = _isDesktop && isLibrary;
        bool canSelect = video.compressionStatus.toLowerCase() == 'waiting';

        return VideoCard(
          video: video,
          showActions: showActions,
          isSelectionMode: showCheckbox,
          onSelectionChanged: canSelect 
              ? (val) => setState(() => video.isSelected = val!) 
              : null,
          onApprove: () => _handleApprove(video),
          onDelete: () => _handleDelete(video),
          onPlay: () => _handlePlay(video), 
        );
      },
    );
  }

  // --- ACTIONS ---

  Future<void> _handleApprove(VideoModel video) async {
    String currentStatus = video.adminStatus.toLowerCase();
    String nextStatus = (currentStatus == 'pending') ? 'reviewed' : 'Approved';

    await _dbService.updateStatus(video.id, {'adminStatus': nextStatus});
    _showSnack("Status updated to $nextStatus", Colors.black87);
    _loadData(); 
  }

  Future<void> _handleDelete(VideoModel video) async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Delete Video?"),
      content: Text("This will permanently remove the video."),
      actions: [
        TextButton(onPressed:()=>Navigator.pop(c,false),child:Text("Cancel")),
        TextButton(onPressed:()=>Navigator.pop(c,true),child:Text("Delete", style: TextStyle(color:Colors.red))),
      ],
    )) ?? false;
    
    if (!confirm) return;

    if (video.sourceFileId.isNotEmpty) {
      await _r2Service.deleteFile(video.sourceFileId);
    }
    await _dbService.deleteDocument(video.id);
    
    _showSnack("Deleted '${video.title}'", Colors.black87);
    _loadData();
  }

  Future<void> _triggerCompression(List<VideoModel> videos) async {
    for (var v in videos) {
      await _dbService.updateStatus(v.id, {'compressionStatus': 'queued'});
    }
    _showSnack("Queued ${videos.length} videos", Colors.blueAccent);
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