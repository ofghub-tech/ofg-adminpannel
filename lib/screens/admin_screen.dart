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

    String? secureUrl = await _r2Service.getPresignedUrl(video.sourceFileId);
    if (mounted) Navigator.pop(context);

    if (secureUrl != null && mounted) {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (_) => PlayerScreen(videoUrl: secureUrl, title: video.title)
        )
      );
    } else if (mounted) {
      _showSnack("Could not generate playback URL (File missing?)", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. FILTER LISTS FOR 3 LAYERS
    var pendingList = _filteredVideos.where((v) => v.adminStatus.toLowerCase() == 'pending').toList();
    var reviewedList = _filteredVideos.where((v) => v.adminStatus.toLowerCase() == 'reviewed').toList();
    var approvedList = _filteredVideos.where((v) => v.adminStatus.toLowerCase() == 'approved').toList();
    
    int selectedCount = approvedList.where((v) => v.isSelected).length;

    return DefaultTabController(
      length: 3, // CHANGED TO 3 TABS
      child: Scaffold(
        backgroundColor: Color(0xFFF5F5F7),
        appBar: AppBar(
          title: Text("OFG Connects"),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(100),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search title or user...",
                      prefixIcon: Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      hintStyle: TextStyle(color: Colors.white60),
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                  ),
                ),
                TabBar(
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: [
                    Tab(text: "INBOX (${pendingList.length})"),
                    Tab(text: "REVIEW (${reviewedList.length})"), // NEW TAB
                    Tab(text: "LIBRARY (${approvedList.length})"),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            IconButton(icon: Icon(Icons.refresh), onPressed: _loadData),
            IconButton(icon: Icon(Icons.logout), onPressed: _handleLogout),
          ],
        ),
        body: _isLoading 
            ? Center(child: CircularProgressIndicator()) 
            : TabBarView(
                children: [
                  _buildList(pendingList, showActions: true),  // Step 1
                  _buildList(reviewedList, showActions: true), // Step 2
                  _buildList(approvedList, showActions: false),// Final
                ],
              ),
        
        floatingActionButton: selectedCount > 0 
          ? FloatingActionButton.extended(
              backgroundColor: Color(0xFF009688),
              icon: Icon(Icons.compress, color: Colors.white),
              label: Text("Compress $selectedCount", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _triggerCompression(approvedList.where((v) => v.isSelected).toList()),
            )
          : null,
      ),
    );
  }

  Widget _buildList(List<VideoModel> list, {required bool showActions}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 48, color: Colors.grey[300]),
            SizedBox(height: 10),
            Text("No videos found", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 12, bottom: 80),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final video = list[i];
        
        if (showActions) {
          // PENDING & REVIEW TABS: Show Actions
          return VideoCard(
            video: video,
            isSelectionMode: false,
            onApprove: () => _handleApprove(video),
            onDelete: () => _handleDelete(video),
            onPlay: () => _handlePlay(video), 
          );
        } else {
          // APPROVED TAB: Show Checkboxes
          bool canSelect = video.compressionStatus.toLowerCase() == 'waiting';
          
          return VideoCard(
            video: video,
            isSelectionMode: true,
            onSelectionChanged: canSelect
                ? (val) => setState(() => video.isSelected = val!)
                : null,
            onPlay: () => _handlePlay(video),
          );
        }
      },
    );
  }

  // --- ACTIONS ---

  Future<void> _handleApprove(VideoModel video) async {
    // 2-LAYER LOGIC
    String currentStatus = video.adminStatus.toLowerCase();
    String nextStatus;
    String message;

    if (currentStatus == 'pending') {
      nextStatus = 'reviewed';
      message = "Moved '${video.title}' to Review (Step 1 Complete)";
    } else {
      nextStatus = 'Approved'; // Capitalized as per your original code
      message = "Fully Approved '${video.title}'";
    }

    await _dbService.updateStatus(video.id, {'adminStatus': nextStatus});
    _showSnack(message, Colors.green);
    _loadData(); 
  }

  Future<void> _handleDelete(VideoModel video) async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Delete Video?"),
      content: Text("This will permanently remove the raw file from Cloudflare R2 and the database."),
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
    
    _showSnack("Deleted '${video.title}'", Colors.grey[800]!);
    _loadData();
  }

  Future<void> _triggerCompression(List<VideoModel> videos) async {
    for (var v in videos) {
      await _dbService.updateStatus(v.id, {'compressionStatus': 'queued'});
    }
    _showSnack("Sent ${videos.length} videos to Compression Engine", Colors.deepPurple);
    _loadData();
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}