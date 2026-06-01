import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:video_player/video_player.dart';
import 'package:media_cast_dlna/media_cast_dlna.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String videoTitle;

  const VideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  final YoutubeExplode _yt = YoutubeExplode();

  List<MuxedStreamInfo> _availableStreams = [];
  MuxedStreamInfo? _currentStream;
  bool _isFullScreen = false;

  // Manejo de la transmisión por DLNA
  final MediaCastDlna _dlnaApi = MediaCastDlna();
  DlnaDevice? _connectedDevice;
  bool _isCasting = false;

  @override
  void initState() {
    super.initState();
    _loadVideoStreams();
  }

  Future<void> _loadVideoStreams() async {
    try {
      final manifest =
          await _yt.videos.streamsClient.getManifest(widget.videoId);

      final Map<String, MuxedStreamInfo> uniqueStreams = {};
      for (var stream in manifest.muxed) {
        uniqueStreams[stream.qualityLabel] = stream;
      }

      _availableStreams = uniqueStreams.values.toList();
      _availableStreams
          .sort((a, b) => b.videoQuality.index.compareTo(a.videoQuality.index));

      if (_availableStreams.isNotEmpty) {
        _currentStream = _availableStreams.first;
        await _initializePlayer(_currentStream!.url);
      } else {
        throw Exception("No se encontraron streams válidos");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _initializePlayer(Uri url, {Duration? startPosition}) async {
    if (_controller != null) {
      await _controller!.pause();
      await _controller!.dispose();
      _controller = null;
    }

    _controller = VideoPlayerController.networkUrl(url);

    try {
      await _controller!.initialize();
      if (startPosition != null) {
        await _controller!.seekTo(startPosition);
      }
      if (mounted) {
        setState(() => _isLoading = false);
        if (!_isCasting) _controller?.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _changeQuality(MuxedStreamInfo newStream) async {
    if (_currentStream == newStream || _controller == null) return;

    setState(() => _isLoading = true);
    final currentPosition = _controller!.value.position;
    _currentStream = newStream;

    await _initializePlayer(newStream.url, startPosition: currentPosition);
    if (_isCasting) _sendVideoToTv();
  }

  void _showCastDevicesDialog() async {
    setState(() => _isLoading = true);

    List<DlnaDevice> devices = await _dlnaApi.searchDevices();

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se encontraron Smart TV o Android TV en la red')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transmitir a dispositivo'),
        backgroundColor: const Color(0xFF212121),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: const Icon(Icons.tv, color: Colors.white),
                title: Text(device.friendlyName,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _connectAndCast(device);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _connectAndCast(DlnaDevice device) async {
    if (_currentStream == null) return;
    setState(() {
      _isCasting = true;
      _connectedDevice = device;
    });
    _controller?.pause();
    _sendVideoToTv();
  }

  void _sendVideoToTv() async {
    if (_currentStream != null && _connectedDevice != null) {
      await _dlnaApi.castVideo(
        device: _connectedDevice!,
        videoUrl: _currentStream!.url.toString(),
        title: widget.videoTitle,
      );
    }
  }

  void _disconnectCast() async {
    if (_connectedDevice != null) {
      await _dlnaApi.stop(device: _connectedDevice!);
    }
    setState(() {
      _isCasting = false;
      _connectedDevice = null;
    });
    _controller?.play();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller?.dispose();
    _yt.close();
    super.dispose();
  }

  String _formatDuration(Duration position) {
    final minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    Widget videoWidget = Container(
      color: Colors.black,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _hasError
              ? const Center(
                  child: Text('Error al cargar el video sin anuncios'))
              : _isCasting
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cast_connected,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 10),
                          Text(
                              'Transmitiendo en ${_connectedDevice?.friendlyName ?? "la TV"}...',
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 15),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: _disconnectCast,
                            child: const Text('Detener transmisión',
                                style: TextStyle(color: Colors.white)),
                          )
                        ],
                      ),
                    )
                  : _controller != null && _controller!.value.isInitialized
                      ? Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(_controller!),
                            _buildControls(),
                          ],
                        )
                      : const Center(child: Text('Cargando flujo...')),
    );

    // CONTROL INTELIGENTE: Interceptamos el botón volver usando PopScope
    return PopScope(
      canPop:
          !_isFullScreen, // Si no está en pantalla completa, permite cerrar la pantalla normalmente
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Si el usuario presiona "atrás" en horizontal, sólo cancela la pantalla completa y vuelve a vertical
        if (_isFullScreen) {
          _toggleFullScreen();
        }
      },
      child: _buildPlayerLayout(videoWidget),
    );
  }

  // Renderiza la estructura visual según el estado de la pantalla
  Widget _buildPlayerLayout(Widget videoWidget) {
    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: _controller?.value.isInitialized == true
                ? _controller!.value.aspectRatio
                : 16 / 9,
            child: videoWidget,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproductor Lite'),
        actions: [
          IconButton(
            icon: Icon(_isCasting ? Icons.cast_connected : Icons.cast,
                color: Colors.white),
            onPressed: _isCasting ? _disconnectCast : _showCastDevicesDialog,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: videoWidget,
          ),
          if (!_isLoading && !_hasError && _availableStreams.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: const Text('Calidad del video',
                  style: TextStyle(fontSize: 14)),
              trailing: DropdownButton<MuxedStreamInfo>(
                value: _currentStream,
                dropdownColor: const Color(0xFF212121),
                underline: const SizedBox(),
                items: _availableStreams.map((stream) {
                  return DropdownMenuItem<MuxedStreamInfo>(
                    value: stream,
                    child: Text(
                      stream.qualityLabel,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (MuxedStreamInfo? newStream) {
                  if (newStream != null) _changeQuality(newStream);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.videoTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return ValueListenableBuilder(
      valueListenable: _controller!,
      builder: (context, VideoPlayerValue value, child) {
        return Container(
          color: Colors.black38,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.red,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                            value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white),
                        onPressed: () {
                          value.isPlaying
                              ? _controller?.pause()
                              : _controller?.play();
                        },
                      ),
                      Text(
                        '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white,
                    ),
                    onPressed: _toggleFullScreen,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
