import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class PlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const PlayerScreen({Key? key, required this.videoUrl, required this.title}) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController.initialize();

      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: true,
          looping: false,
          aspectRatio: _videoPlayerController.value.aspectRatio,
          errorBuilder: (context, errorMessage) {
            return Center(child: Text("Playback Error: $errorMessage", style: TextStyle(color: Colors.white)));
          },
        );
      });
    } catch (e) {
      print("Video Init Error: $e");
      setState(() => _isError = true);
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(widget.title, style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Center(
        child: _isError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 10),
                  Text("Could not play video.", style: TextStyle(color: Colors.white)),
                  Text("Check internet or file validity.", style: TextStyle(color: Colors.grey)),
                ],
              )
            : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}