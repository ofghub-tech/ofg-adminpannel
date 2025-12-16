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

  // ---------------------------------------------------------
  // PLATFORM CHECK: Returns TRUE only if running on Desktop
  // ---------------------------------------------------------
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
    if (_allVideos.isEmpty) setState(() => _isLoading = true);
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
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
  }

  Future<void> _handlePlay(VideoModel video) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    String? secureUrl = await _r2Service.getPresignedUrl(video.sourceFileId);
    if (mounted) Navigator.pop(context);
    if (secureUrl != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(videoUrl: secureUrl, title: video.title)));
    }
  }

  Future<void> _handleApprove(VideoModel video) async {
    String current = video.adminStatus.toLowerCase();
    String next = current == 'pending' ? 'reviewed' : 'Approved';
    await _dbService.updateStatus(video.id, {'adminStatus': next});
    _loadData();
    _showSnack("Status updated", Colors.black87);
  }

  Future<void> _handleDelete(VideoModel video) async {
    bool confirm = await showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text("Delete Video"),
              content: const Text("Are you sure?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
              ],
            )) ?? false;

    if (!confirm) return;
    if (video.sourceFileId.isNotEmpty) await _r2Service.deleteFile(video.sourceFileId);
    await _dbService.deleteDocument(video.id);
    _loadData();
    _showSnack("Video deleted", Colors.black87);
  }

  Future<void> _triggerCompression(List<VideoModel> videos) async {
    for (var v in videos) {
      await _dbService.updateStatus(v.id, {'compressionStatus': 'queued'});
    }
    _showSnack("Queued ${videos.length} videos", Colors.blueAccent);
    _loadData();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    var pending = _filteredVideos.where((v) => v.adminStatus.toLowerCase() == 'pending').toList();
    var reviewed = _filteredVideos.where((v) => v.adminStatus.toLowerCase() == 'reviewed').toList();
    var approved = _filteredVideos.where((v) => v.adminStatus.toLowerCase() == 'approved').toList();

    int selectedCount = approved.where((v) => v.isSelected).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Connects Admin"),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
            IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Search...",
                        prefixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  TabBar(
                    labelColor: const Color(0xFF0F172A),
                    unselectedLabelColor: const Color(0xFF94A3B8),
                    indicatorColor: const Color(0xFF3B82F6),
                    tabs: [
                      Tab(text: "Inbox (${pending.length})"),
                      Tab(text: "Review (${reviewed.length})"),
                      Tab(text: "Library (${approved.length})"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildList(pending, isLibrary: false),
                  _buildList(reviewed, isLibrary: false),
                  // "Library" tab: Actions hidden, but if Desktop, Checkboxes shown
                  _buildList(approved, isLibrary: true),
                ],
              ),
        // FLOATING ACTION BUTTON: ONLY SHOW IF DESKTOP & ITEMS SELECTED
        floatingActionButton: (_isDesktop && selectedCount > 0)
            ? FloatingActionButton.extended(
                backgroundColor: const Color(0xFF0F172A),
                icon: const Icon(Icons.compress, color: Colors.white),
                label: Text("Compress ($selectedCount)", style: const TextStyle(color: Colors.white)),
                onPressed: () => _triggerCompression(approved.where((v) => v.isSelected).toList()),
              )
            : null,
      ),
    );
  }

  Widget _buildList(List<VideoModel> list, {required bool isLibrary}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            Text("No videos here", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final video = list[i];
        
        // LOGIC: Enable selection ONLY if Desktop AND in Library AND compression is 'waiting'
        bool showCheckbox = _isDesktop && isLibrary;
        bool canSelect = video.compressionStatus.toLowerCase() == 'waiting';

        return VideoCard(
          video: video,
          showActions: !isLibrary, // Show Approve/Reject only in Inbox/Review tabs
          isSelectionMode: showCheckbox,
          onSelectionChanged: canSelect ? (val) => setState(() => video.isSelected = val!) : null,
          onApprove: () => _handleApprove(video),
          onDelete: () => _handleDelete(video),
          onPlay: () => _handlePlay(video),
        );
      },
    );
  }
}