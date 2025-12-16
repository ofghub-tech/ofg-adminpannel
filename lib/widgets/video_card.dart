import 'package:flutter/material.dart';
import '../models/video_model.dart';

class VideoCard extends StatelessWidget {
  final VideoModel video;
  final bool showActions;
  final bool isSelectionMode;
  final VoidCallback? onApprove;
  final VoidCallback? onDelete;
  final VoidCallback? onPlay;
  final ValueChanged<bool?>? onSelectionChanged;

  const VideoCard({
    Key? key,
    required this.video,
    required this.showActions,
    this.isSelectionMode = false,
    this.onApprove,
    this.onDelete,
    this.onPlay,
    this.onSelectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // LOGIC: If selection mode is on, clicking the card body selects/deselects.
        // Otherwise, it plays the video.
        onTap: isSelectionMode 
            ? () { if (onSelectionChanged != null) onSelectionChanged!(!video.isSelected); }
            : onPlay,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // --- THUMBNAIL (ALWAYS PLAYABLE) ---
              GestureDetector(
                onTap: onPlay, // <--- IMPORTANT: Thumbnail tap always plays!
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 90,
                    height: 60,
                    color: const Color(0xFFF1F5F9),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (video.thumbnailUrl.isNotEmpty)
                          Image.network(video.thumbnailUrl, fit: BoxFit.cover, width: 90, height: 60),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // INFO
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "by ${video.username}",
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusPill(),
                  ],
                ),
              ),

              // ACTIONS or CHECKBOX
              if (isSelectionMode)
                Checkbox(
                  value: video.isSelected,
                  onChanged: onSelectionChanged,
                  activeColor: const Color(0xFF0F172A),
                )
              else if (showActions)
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        video.adminStatus.toLowerCase() == 'pending' ? Icons.check_circle_outline : Icons.done_all,
                        color: Colors.green,
                      ),
                      onPressed: onApprove,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: onDelete,
                    ),
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    Color bg;
    Color text;
    String label = video.adminStatus;
    // Normalize status strings
    String status = label.toLowerCase();
    String compression = video.compressionStatus.toLowerCase();

    if (status == 'pending') {
      bg = const Color(0xFFFFF7ED); // Orange
      text = const Color(0xFFC2410C);
    } else if (status == 'reviewed') {
      bg = const Color(0xFFEFF6FF); // Blue
      text = const Color(0xFF1D4ED8);
    } else {
      bg = const Color(0xFFF0FDF4); // Green
      text = const Color(0xFF15803D);
    }

    // Override label if compression is queued or processing
    if (status == 'approved' && (compression == 'queued' || compression == 'processing')) {
      label = "Processing...";
      bg = const Color(0xFFFAF5FF); // Purple
      text = const Color(0xFF7E22CE);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}