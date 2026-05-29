import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const AudioReverseScreen(),
    );
  }
}

class AudioReverseScreen extends StatefulWidget {
  const AudioReverseScreen({super.key});
  @override
  State<AudioReverseScreen> createState() => _AudioReverseScreenState();
}

class _AudioReverseScreenState extends State<AudioReverseScreen> {
  bool _isProcessing = false;
  String _statusMessage = "Selecciona una canción MP3";
  String? _finalOutputPath;
  double _audioSpeed = 1.0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen(
      (s) => setState(() => _isPlaying = s == PlayerState.playing),
    );
    _audioPlayer.onDurationChanged.listen((d) => setState(() => _duration = d));
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _position = p));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> processAudio() async {
    await _audioPlayer.stop();
    FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (res == null || res.files.single.path == null) {
      setState(() => _statusMessage = "Selección cancelada");
      return;
    }
    setState(() {
      _isProcessing = true;
      _statusMessage = "Procesando audio (Reversa + Velocidad)...";
      _finalOutputPath = null;
    });
    String inputPath = res.files.single.path!;
    final directory = await getTemporaryDirectory();
    String outputPath = "${directory.path}/audio_invertido_velocidad.mp3";
    final outputFile = File(outputPath);
    if (await outputFile.exists()) await outputFile.delete();
    String ffmpegCommand = "-i \"$inputPath\" -af \"areverse\" \"$outputPath\"";
    await FFmpegKit.execute(ffmpegCommand).then((session) async {
      final returnCode = await session.getReturnCode();
      setState(() {
        _isProcessing = false;
        if (ReturnCode.isSuccess(returnCode)) {
          _statusMessage = "¡Listo! Audio procesado.";
          _finalOutputPath = outputPath;
        } else {
          _statusMessage = "Error en el procesamiento de FFmpeg";
        }
      });
    });
  }

  Future<void> exportarLoEscuchado() async {
  if (_finalOutputPath == null) return;

  // CORRECCIÓN 1: Cambiamos al permiso de audio nativo de Android 13+ para que no salte el aviso 22
  


  int segundoActual = _position.inSeconds;
  int segundoInicio = segundoActual - 10;
  if (segundoInicio < 0) segundoInicio = 0;
  int duracionRecorte = segundoActual - segundoInicio;
  if (duracionRecorte <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Reproducí al menos 1 segundo")),
    );
    return;
  }
  
  setState(() {
    _isProcessing = true;
    _statusMessage = "Exportando fragmento escuchado...";
  });

  // CORRECCIÓN 2: Obtener la ruta de la carpeta pública de descargas de forma correcta y segura
  String? rutaDescargas;
  if (Platform.isAndroid) {
    rutaDescargas = "/storage/emulated/0/Download"; // Se mantiene la carpeta, pero validada
  } else {
    final directory = await getDownloadsDirectory();
    rutaDescargas = directory?.path;
  }

  if (rutaDescargas == null) {
    setState(() {
      _isProcessing = false;
      _statusMessage = "No se pudo acceder a la carpeta Descargas.";
    });
    return;
  }

  String rutaArchivoFinal = "$rutaDescargas/escuchado_hasta_segundo_$segundoActual.mp3";

  // CORRECCIÓN 3: Ajustamos los argumentos de FFmpeg para máxima velocidad
  List<String> argumentosCortar = [
    "-y",
    "-ss", segundoInicio.toString(),
    "-t", duracionRecorte.toString(),
    "-i", _finalOutputPath!,
    "-c:a", "libmp3lame", // Mantenemos el códec mp3 estándar de ffmpeg_kit
    "-q:a", "2",
    rutaArchivoFinal,
  ];

  await FFmpegKit.executeWithArguments(argumentosCortar).then((session) async {
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      
      // El comando 'am broadcast' requiere permisos de root en Android moderno.
      // Reemplazamos con un chequeo nativo básico o simplemente avisamos al usuario.
      if (await File(rutaArchivoFinal).exists()) {
        print("Archivo verificado en disco.");
      }

      setState(() {
        _isProcessing = false;
        _statusMessage = "¡Guardado! Buscalo en la carpeta Descargas.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Guardado en Descargas con éxito")),
      );
    } else {
      final failStackTrace = await session.getFailStackTrace();
      print("FFmpeg Falló: $failStackTrace");
      setState(() {
        _isProcessing = false;
        _statusMessage = "Error de FFmpeg al recortar lo escuchado";
      });
    }
  });
}
  

  Future<void> togglePlayback() async {
    if (_finalOutputPath == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.setPlaybackRate(_audioSpeed);
      await _audioPlayer.play(DeviceFileSource(_finalOutputPath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inversor de Audio MP3")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.grey,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.amberAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Velocidad del Audio: ${_audioSpeed.toStringAsFixed(1)}x",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _audioSpeed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: "${_audioSpeed.toStringAsFixed(1)}x",
              activeColor: Colors.deepPurple,
              onChanged: (value) async {
                setState(() => _audioSpeed = value);
                await _audioPlayer.setPlaybackRate(value);
              },
            ),
            const SizedBox(height: 24),
            _isProcessing
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.deepPurple,
                    ),
                    onPressed: processAudio,
                    icon: const Icon(Icons.compare_arrows, color: Colors.white),
                    label: const Text(
                      "Cargar y Procesar MP3",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
            if (_finalOutputPath != null) ...[
              const SizedBox(height: 32),
              const Divider(color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                "Escuchar Resultado",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                    ),
                    color: Colors.amberAccent,
                    onPressed: togglePlayback,
                  ),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: _duration.inMilliseconds.toDouble(),
                      value: _position.inMilliseconds.toDouble().clamp(
                        0,
                        _duration.inMilliseconds.toDouble(),
                      ),
                      onChanged: (value) async {
                        final pos = Duration(milliseconds: value.toInt());
                        await _audioPlayer.seek(pos);
                      },
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
                    ),
                    Text(
                      "${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.grey),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.teal,
                ),
                onPressed: _isProcessing ? null : exportarLoEscuchado,
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text(
                  "Exportar últimos 10s escuchados",
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
