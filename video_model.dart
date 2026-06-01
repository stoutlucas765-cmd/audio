class YouTubeVideo {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration? duration;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.duration,
  });
}