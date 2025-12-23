class VideoModel {
  String id;
  String title;
  String thumbnailUrl;
  String adminStatus;        // 'pending', 'reviewed', 'approved'
  String compressionStatus;  // 'waiting', 'queued', 'processing', 'done'
  String sourceFileId;       // R2 Filename
  String videoUrl;           // Direct Playable URL
  String username;
  String email;              // <--- NEW: User's email address
  bool isSelected;

  VideoModel({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.adminStatus,
    required this.compressionStatus,
    required this.sourceFileId,
    required this.videoUrl,
    required this.username,
    required this.email,
    this.isSelected = false,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['\$id'],
      title: json['title'] ?? 'No Title',
      thumbnailUrl: json['thumbnailUrl'] != null ? json['thumbnailUrl'].toString() : '',
      adminStatus: json['adminStatus'] ?? 'pending',
      compressionStatus: json['compressionStatus'] ?? 'waiting',
      sourceFileId: json['sourceFileId'] ?? '',
      videoUrl: json['videoUrl'] ?? json['url_4k'] ?? '',
      username: json['username'] ?? 'Unknown',
      // Ensure your Appwrite collection has an 'email' field, or this will be empty
      email: json['email'] ?? '', 
    );
  }
}