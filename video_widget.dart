import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoMessage extends StatefulWidget {
  final String url;
  const VideoMessage({super.key, required this.url});

  @override
  State<VideoMessage> createState() => _VideoMessageState();
}

class _VideoMessageState extends State<VideoMessage> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    // On prépare la vidéo
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));

    _videoController.initialize().then((_) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          aspectRatio: _videoController.value.aspectRatio,
          autoPlay: false,
          looping: false,
        );
      });
    });
  }

  @override
  void dispose() {
    // On libère la mémoire quand on ferme le chat
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController != null && _videoController.value.isInitialized) {
      return Container(
        height: 250,
        child: Chewie(controller: _chewieController!),
      );
    } else {
      return const Center(
        child: CircularProgressIndicator(), // Chargement en attendant la vidéo
      );
    }
  }
}
