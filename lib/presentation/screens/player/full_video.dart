part of '../screens.dart';


class FullVideoScreen extends StatefulWidget {
  const FullVideoScreen({
    super.key,
    required this.link,
    required this.title,
    this.isLive = false,
  });

  final String link;
  final String title;
  final bool isLive;

  @override
  State<FullVideoScreen> createState() => _FullVideoScreenState();
}

class _FullVideoScreenState extends State<FullVideoScreen> {
  late VlcPlayerController _videoPlayerController;
  bool isPlayed = true;
  bool progress = true;
  bool showControllersVideo = true;
  String position = '00:00';
  String duration = '00:00';
  double sliderValue = 0.0;
  bool validPosition = false;
  bool _isSeeking = false;
  late Timer _hideControlsTimer = Timer(Duration.zero, () {});

  double _currentVolume = 0.5;
  double _currentBright = 0.5;

  List<Map<String, dynamic>> _subtitleTracks = [];
  List<Map<String, dynamic>> _audioTracks = [];
  int? _selectedSubtitle;
  int? _selectedAudioTrack;

  static const platform = MethodChannel('com.tv.fifi/overlay');

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Evita que la pantalla se apague
    _initializePlayer();
    _initializeSettings();
    _setupPlatformHandler();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startHideControlsTimer();
    });
  }

  void _initializePlayer() {
    _videoPlayerController = VlcPlayerController.network(
      widget.link,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      autoInitialize: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          "--sub-autodetect-file",
          "--audio-track=0",
          "--avcodec-threads=2",
        ]),
      ),
    );

    _videoPlayerController.addListener(_updateVideoPosition);
    _videoPlayerController.addOnInitListener(() async {
      debugPrint("Reproductor inicializado, iniciando reproducción...");
      if (_videoPlayerController.value.isInitialized) {
        await _videoPlayerController.play();
        _loadTracks();
      } else {
        debugPrint("⚠ El reproductor no se inicializó correctamente.");
      }
    });
  }

  void _initializeSettings() async {
    try {
      _currentBright = await ScreenBrightness.instance.application;
      _currentVolume = await VolumeController.instance.getVolume();
      setState(() {});
    } catch (e) {
      debugPrint("Error al inicializar configuraciones: $e");
    }
  }

  void _setupPlatformHandler() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "onOverlayClosed") {
        int position = call.arguments['position'] ?? 0;
        bool wasPlaying = call.arguments['isPlaying'] ?? true;

        _videoPlayerController.setTime(position);
        if (wasPlaying) {
          await _videoPlayerController.play();
        }
        setState(() {
          isPlayed = wasPlaying;
        });
      }
    });
  }

  Future<void> openFloatingWindow() async {
    try {
      int position = _videoPlayerController.value.position.inMilliseconds;
      bool isPlaying = _videoPlayerController.value.isPlaying;

      await platform.invokeMethod('showOverlay', {
        'videoUrl': _videoPlayerController.dataSource,
        'position': position,
        'isPlaying': isPlaying,
      });

      await _videoPlayerController.pause();
      setState(() {
        isPlayed = false;
      });
    } on PlatformException catch (e) {
      debugPrint("Error al abrir la ventana flotante: ${e.message}");
    }
  }

  Future<void> _loadTracks() async {
    try {
      int intentos = 0;
      const int maxIntentos = 5;
      List<Map<String, dynamic>> nuevosSubtitulos = [];
      List<Map<String, dynamic>> nuevasPistasAudio = [];

      while (intentos < maxIntentos) {
        final subtitleTracksRaw = await _videoPlayerController.getSpuTracks();
        final audioTracksRaw = await _videoPlayerController.getAudioTracks();

        if (subtitleTracksRaw.isNotEmpty || audioTracksRaw.isNotEmpty) {
          nuevosSubtitulos = subtitleTracksRaw.entries
              .map((entry) => {"id": entry.key, "name": entry.value})
              .toList();
          nuevasPistasAudio = audioTracksRaw.entries
              .map((entry) => {"id": entry.key, "name": entry.value})
              .toList();
          break;
        }

        intentos++;
        await Future.delayed(Duration(seconds: 3));
      }

      setState(() {
        _subtitleTracks = nuevosSubtitulos;
        _audioTracks = nuevasPistasAudio;
      });

      debugPrint("🎥 Subtítulos detectados: $_subtitleTracks");
      debugPrint("🔊 Pistas de audio detectadas: $_audioTracks");
    } catch (e) {
      debugPrint("❌ Error al obtener pistas: $e");
    }
  }

  void _updateVideoPosition() {
    if (!mounted || !_videoPlayerController.value.isInitialized) return;
    final currentPos = _videoPlayerController.value.position;
    final totalDuration = _videoPlayerController.value.duration;

    setState(() {
      position = _formatDuration(currentPos);
      duration = _formatDuration(totalDuration);
      validPosition = totalDuration.compareTo(currentPos) >= 0;
      if (!_isSeeking) {
        sliderValue = currentPos.inSeconds.toDouble();
      }
      progress = false;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
    } else {
      return "${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds % 60)}";
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_videoPlayerController.value.isInitialized) return;

    if (_videoPlayerController.value.isPlaying) {
      debugPrint("⏸ Intentando pausar...");
      await _videoPlayerController.pause();
      await Future.delayed(Duration(milliseconds: 500));

      if (_videoPlayerController.value.isPlaying) {
        debugPrint("❌ Error: El video no se pausó, forzando pausa...");
        await _videoPlayerController.pause();
      } else {
        debugPrint("✅ Pausa exitosa.");
      }
    } else {
      debugPrint("▶ Intentando reproducir...");
      await _videoPlayerController.play();
    }

    setState(() {
      isPlayed = _videoPlayerController.value.isPlaying;
    });
  }

  void _onSliderPositionChanged(double value) {
    if (!_videoPlayerController.value.isInitialized) return;
    setState(() {
      sliderValue = value;
      _isSeeking = true;
    });
  }

  void _onSliderChangeEnd(double value) async {
    if (!_videoPlayerController.value.isInitialized) return;
    await _videoPlayerController.setTime((value * 1000).toInt());
    setState(() => _isSeeking = false);
  }

  Future<void> castVideo(String url) async {
    const platform = MethodChannel('com.tv.fifi/cast');
    try {
      await platform.invokeMethod('castVideo', {
        'url': url,
      });
    } on PlatformException catch (e) {
      debugPrint("❌ Error al transmitir: ${e.message}");
    }
  }

  void _toggleControls() {
    setState(() {
      showControllersVideo = !showControllersVideo;
    });
    if (showControllersVideo) {
      _startHideControlsTimer();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer.cancel();
    _hideControlsTimer = Timer(Duration(seconds: 5), () {
      if (mounted) {
        setState(() => showControllersVideo = false);
      }
    });
  }

  String _truncateText(String text, int maxLength) {
    return text.length > maxLength ? '${text.substring(0, maxLength)}...' : text;
  }

  Widget _buildDropdownButton(
      String title,
      List<Map<String, dynamic>> items,
      int? selectedValue,
      Function(int?) onChanged,
      ) {
    return DropdownButton<int>(
      dropdownColor: Colors.black,
      value: (selectedValue != null && selectedValue != -1) ? selectedValue : null,
      hint: Text(title, style: const TextStyle(color: Colors.white)),
      items: [
        const DropdownMenuItem<int>(
          value: -1,
          child: Text("Subtitles Off", style: TextStyle(color: Colors.white)),
        ),
        ...items.map((track) {
          final int trackId = (track["id"] as num).toInt();
          final String trackName = _truncateText(track["name"].toString(), 25);
          return DropdownMenuItem<int>(
            value: trackId,
            child: Text(trackName, style: const TextStyle(color: Colors.white)),
          );
        }).toList(),
      ],
      onChanged: (int? newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }

  void _changeSubtitle(int? trackId) {
    if (trackId == null) return;

    if (trackId == _selectedSubtitle) {
      // Si el usuario selecciona la misma pista activa, se desactivan los subtítulos
      _videoPlayerController.setSpuTrack(-1);
      setState(() {
        _selectedSubtitle = -1; // Indica que no hay subtítulos activos
      });
      debugPrint("🛑 Subtítulos desactivados");
    } else {
      // Si el usuario selecciona una pista nueva, se cambia el subtítulo
      _videoPlayerController.setSpuTrack(trackId);
      setState(() {
        _selectedSubtitle = trackId;
      });
      debugPrint("✅ Subtítulos cambiados a ID: $trackId");
    }
  }

  void _changeAudioTrack(int? trackId) {
    if (trackId == null || trackId == -1) return;
    _videoPlayerController.setAudioTrack(trackId);
    setState(() {
      _selectedAudioTrack = trackId;
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _hideControlsTimer.cancel();
    _videoPlayerController.dispose();
    VolumeController.instance.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: VlcPlayer(
                controller: _videoPlayerController,
                aspectRatio: 16 / 9,
                virtualDisplay: true,
                placeholder: progress
                    ? const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                )
                    : const SizedBox(),
              ),
            ),

            if (showControllersVideo)
              Positioned.fill(
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: openFloatingWindow,
                            icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cast, color: Colors.white),
                            onPressed: () {
                              castVideo(widget.link);
                            },
                          ),
                        ],
                      ),

                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!isTv(context))
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.brightness_6, color: Colors.white),
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    height: 120,
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: Slider(
                                        value: _currentBright,
                                        min: 0.0,
                                        max: 1.0,
                                        activeColor: Colors.white,
                                        onChanged: (value) async {
                                          setState(() => _currentBright = value);
                                          await ScreenBrightness.instance.setApplicationScreenBrightness(value);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (!isTv(context))
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.volume_up, color: Colors.white),
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    height: 120,
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: Slider(
                                        value: _currentVolume,
                                        min: 0.0,
                                        max: 1.0,
                                        activeColor: Colors.white,
                                        onChanged: (value) {
                                          setState(() => _currentVolume = value);
                                          VolumeController.instance.setVolume(value);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 50,
                            child: IconButton(
                              icon: Icon(
                                isPlayed ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                size: 50,
                                color: Colors.white,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                          ),
                          if (!widget.isLive)
                            Slider(
                              value: sliderValue,
                              min: 0,
                              max: _videoPlayerController.value.duration.inSeconds.toDouble(),
                              activeColor: Colors.purpleAccent,
                              onChanged: _onSliderPositionChanged,
                              onChangeEnd: _onSliderChangeEnd,
                            ),
                          if (!widget.isLive)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildDropdownButton(
                                  "Subtítulos",
                                  _subtitleTracks,
                                  _selectedSubtitle,
                                  _changeSubtitle,
                                ),
                                _buildDropdownButton(
                                  "Audio",
                                  _audioTracks,
                                  _selectedAudioTrack,
                                  _changeAudioTrack,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}