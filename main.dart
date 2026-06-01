import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'video_model.dart';
import 'video_player_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0F0F0F), elevation: 0),
      ),
      home: const MainSearchScreen(),
    );
  }
}

class MainSearchScreen extends StatefulWidget {
  const MainSearchScreen({super.key});

  @override
  State<MainSearchScreen> createState() => _MainSearchScreenState();
}

class _MainSearchScreenState extends State<MainSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<YouTubeVideo>> _videosNotifier = ValueNotifier<List<YouTubeVideo>>([]);
  final ValueNotifier<bool> _isSearchingNotifier = ValueNotifier<bool>(false);
  final YoutubeExplode _yt = YoutubeExplode();

  Future<void> _searchVideos(String query) async {
    if (query.trim().isEmpty) return;
    _isSearchingNotifier.value = true;

    try {
      final searchResult = await _yt.search.search(query);
      final List<YouTubeVideo> loadedVideos = [];

      for (final video in searchResult) {
        loadedVideos.add(YouTubeVideo(
          id: video.id.value,
          title: video.title,
          author: video.author,
          thumbnailUrl: video.thumbnails.mediumResUrl,
          duration: video.duration,
        ));
      }
      _videosNotifier.value = loadedVideos;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al conectar con los servidores')),
        );
      }
    } finally {
      _isSearchingNotifier.value = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _videosNotifier.dispose();
    _isSearchingNotifier.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Lite', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar videos sin anuncios...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF212121),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _searchVideos,
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isSearchingNotifier,
              builder: (context, isSearching, child) {
                if (isSearching) {
                  return const Center(child: CircularProgressIndicator(color: Colors.red));
                }
                return ValueListenableBuilder<List<YouTubeVideo>>(
                  valueListenable: _videosNotifier,
                  builder: (context, videoList, child) {
                    if (videoList.isEmpty) {
                      return const Center(child: Text('Escribe algo para buscar streams directos'));
                    }
                     return ListView.builder(
                      itemCount: videoList.length,
                      itemExtent: 290.0, // Mantenemos la optimización de memoria para el scroll
                      itemBuilder: (context, index) {
                        final video = videoList[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerScreen(
                                  videoId: video.id,
                                  videoTitle: video.title,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: CachedNetworkImage(
                                  imageUrl: video.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.black12),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ),
                              ),
                              // CORRECCIÓN AQUÍ: Agregamos Expanded para absorber el espacio sin desbordar
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        video.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${video.author} • ${video.duration != null ? video.duration.toString().split('.').first : ''}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
