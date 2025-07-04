import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoAudioSwitcher extends StatefulWidget {
  final String audioUrl;
  final Widget child;

  const VideoAudioSwitcher({
    super.key,
    required this.audioUrl,
    required this.child,
  });

  @override
  _VideoAudioSwitcherState createState() => _VideoAudioSwitcherState();
}

class _VideoAudioSwitcherState extends State<VideoAudioSwitcher> with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.tv.fifi/audio');
  bool isAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      print("App minimizada → Activar audio en segundo plano");

      try {
        await _channel.invokeMethod('playAudioBackground', {
          'audioUrl': widget.audioUrl,
        });
        isAudioPlaying = true;
      } catch (e) {
        print("Error iniciando audio en segundo plano: $e");
      }
    }

    if (state == AppLifecycleState.resumed && isAudioPlaying) {
      print("App reanudada → Detener audio en segundo plano");

      try {
        await _channel.invokeMethod('stopAudioBackground');
        isAudioPlaying = false;
      } catch (e) {
        print("Error deteniendo audio en segundo plano: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
