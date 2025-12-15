class VideoModel {
  String id;
  String title;
  String thumbnailUrl;
  String adminStatus;        // 'pending', 'Approved'
  String compressionStatus;  // 'waiting', 'queued', 'processing', 'done'
  String sourceFileId;       // R2 Filename
  String username;
  bool isSelected;

  VideoModel({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.adminStatus,
    required this.compressionStatus,
    required this.sourceFileId,
    required this.username,
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
      username: json['username'] ?? 'Unknown',
    );
  }
}