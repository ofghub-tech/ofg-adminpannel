class VideoModel {
  final String id;
  final String title;
  final String description;
  final String? videoUrl; // Nullable (might be deleted later)
  final String thumbnailUrl;
  final String sourceFileId;
  final String adminStatus; // 'pending', 'reviewed', 'approved'
  
  // --- UI & User Fields ---
  final String username;
  final String email;
  final String compressionStatus; // 'waiting', 'queued', 'processing', 'done'

  // --- Production Quality Fields ---
  final String? url1080p;
  final String? url720p;
  final String? url480p;
  final String? url360p;

  bool isSelected;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    this.videoUrl,
    required this.thumbnailUrl,
    required this.sourceFileId,
    required this.adminStatus,
    
    // Defaults for safety
    this.username = 'Unknown',
    this.email = '',
    this.compressionStatus = 'waiting',
    
    this.isSelected = false,
    this.url1080p,
    this.url720p,
    this.url480p,
    this.url360p,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['\$id'] ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      videoUrl: json['videoUrl'], 
      thumbnailUrl: json['thumbnailUrl'] != null ? json['thumbnailUrl'].toString() : '',
      sourceFileId: json['sourceFileId'] ?? '',
      adminStatus: json['adminStatus'] ?? 'pending',
      
      // Map User Fields (Handle missing data gracefully)
      username: json['username'] ?? 'Unknown',
      email: json['email'] ?? '', 
      compressionStatus: json['compressionStatus'] ?? 'waiting',

      // Map Quality Fields
      url1080p: json['url_1080p'],
      url720p: json['url_720p'],
      url480p: json['url_480p'],
      url360p: json['url_360p'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'sourceFileId': sourceFileId,
      'adminStatus': adminStatus,
      'username': username,
      'email': email,
      'compressionStatus': compressionStatus,
      'url_1080p': url1080p,
      'url_720p': url720p,
      'url_480p': url480p,
      'url_360p': url360p,
    };
  }
}