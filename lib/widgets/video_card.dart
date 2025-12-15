import 'package:flutter/material.dart';
import '../models/video_model.dart';

class VideoCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback? onApprove;
  final VoidCallback? onDelete;
  final VoidCallback? onPlay;
  final bool isSelectionMode;
  final ValueChanged<bool?>? onSelectionChanged;

  const VideoCard({
    Key? key,
    required this.video,
    this.onApprove,
    this.onDelete,
    this.onPlay,
    this.isSelectionMode = false,
    this.onSelectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        // CHANGED: If not in selection mode, onTap triggers Play
        onTap: isSelectionMode 
            ? () => onSelectionChanged!(!video.isSelected) 
            : onPlay, 
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // THUMBNAIL
              GestureDetector(
                onTap: onPlay,
                child: _buildThumbnail(),
              ),
              SizedBox(width: 16),
              
              // DETAILS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(video.username, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    SizedBox(height: 8),
                    _buildStatusChip(),
                  ],
                ),
              ),

              // ACTIONS
              if (isSelectionMode)
                Checkbox(
                  value: video.isSelected,
                  onChanged: onSelectionChanged,
                )
              else
                Column(
                  children: [
                    if (onApprove != null)
                      IconButton(
                        // Dynamic Icon based on status
                        icon: Icon(
                          video.adminStatus.toLowerCase() == 'pending' 
                              ? Icons.check // Step 1 Icon
                              : Icons.check_circle, // Step 2 Icon
                          color: video.adminStatus.toLowerCase() == 'pending' 
                              ? Colors.blue 
                              : Colors.green[600]
                        ),
                        onPressed: onApprove,
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: video.adminStatus.toLowerCase() == 'pending' ? 'Mark Reviewed' : 'Approve',
                      ),
                    SizedBox(height: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                      onPressed: onDelete,
                      constraints: BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 90,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: video.thumbnailUrl.isNotEmpty
                ? Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey),
                  )
                : Center(child: Icon(Icons.movie, color: Colors.grey[400])),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          padding: EdgeInsets.all(4),
          child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
        )
      ],
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;
    String status = video.adminStatus.toLowerCase();
    String compression = video.compressionStatus.toLowerCase();

    if (status == 'pending') {
      color = Colors.orange.shade700;
      text = 'Review Needed';
    } else if (status == 'reviewed') { // NEW STATUS
      color = Colors.blue.shade700;
      text = 'Reviewed';
    } else if (compression == 'done') {
      color = Colors.green.shade700;
      text = 'Live';
    } else if (compression == 'queued') {
      color = Colors.purple.shade600;
      text = 'Queued';
    } else if (compression == 'processing') {
      color = Colors.blue.shade600;
      text = 'Processing';
    } else {
      color = Colors.grey.shade600;
      text = 'Approved';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}