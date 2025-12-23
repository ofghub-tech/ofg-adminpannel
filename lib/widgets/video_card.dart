import 'package:flutter/material.dart';
import '../models/video_model.dart';

class VideoCard extends StatelessWidget {
  final VideoModel video;
  final bool showActions; // Controls if Approve/Delete buttons show
  final bool isSelectionMode;
  final ValueChanged<bool?>? onSelectionChanged;
  final VoidCallback? onApprove;
  final VoidCallback? onDelete;
  final VoidCallback? onPlay;
  final VoidCallback? onEmail; // Added support for email button

  const VideoCard({
    Key? key,
    required this.video,
    this.showActions = true,
    this.isSelectionMode = false,
    this.onSelectionChanged,
    this.onApprove,
    this.onDelete,
    this.onPlay,
    this.onEmail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Logic: If in selection mode, toggle checkbox. If not, Play video.
        onTap: isSelectionMode 
            ? () => onSelectionChanged?.call(!video.isSelected)
            : onPlay,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // THUMBNAIL
              _buildThumbnail(),
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
                    Text("by ${video.username}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    if (video.email.isNotEmpty)
                      Text(video.email, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                    SizedBox(height: 8),
                    _buildStatusChip(),
                  ],
                ),
              ),

              // ACTIONS / CHECKBOX
              if (isSelectionMode)
                Checkbox(
                  value: video.isSelected,
                  onChanged: onSelectionChanged,
                  activeColor: Color(0xFF0F172A),
                )
              else if (showActions)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // APPROVE / VERIFY BUTTON
                    IconButton(
                      icon: Icon(
                        video.adminStatus.toLowerCase() == 'pending' 
                            ? Icons.check_circle_outline 
                            : Icons.check_circle, 
                        color: video.adminStatus.toLowerCase() == 'pending' 
                            ? Colors.blue 
                            : Colors.green
                      ),
                      onPressed: onApprove,
                      tooltip: video.adminStatus.toLowerCase() == 'pending' 
                          ? 'Mark as Reviewed' 
                          : 'Final Approval',
                    ),
                    // DELETE BUTTON
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                      onPressed: onDelete,
                      tooltip: 'Delete Video',
                    ),
                    // EMAIL BUTTON (If email exists)
                    if (video.email.isNotEmpty && onEmail != null)
                       IconButton(
                        icon: Icon(Icons.mail_outline, color: Colors.grey),
                        onPressed: onEmail,
                        tooltip: 'Email User',
                        iconSize: 20,
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
          width: 100,
          height: 65,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: video.thumbnailUrl.isNotEmpty
                ? Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400]),
                  )
                : Center(child: Icon(Icons.movie_creation_outlined, color: Colors.grey[300])),
          ),
        ),
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.play_arrow, color: Colors.white, size: 16),
        ),
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
    } else if (status == 'reviewed') {
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}