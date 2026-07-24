import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/error_messages.dart';

class AudioRecordResult {
  final Uint8List bytes;
  final int durationSeconds;
  AudioRecordResult({required this.bytes, required this.durationSeconds});
}

Future<AudioRecordResult?> showAudioRecorderSheet(
  BuildContext context,
) async {
  DebugConfig.log(DebugConfig.chatAudio, 'AudioRecorderSheet: shown');
  return showModalBottomSheet<AudioRecordResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AudioRecorderSheetContent(),
  );
}

class _AudioRecorderSheetContent extends StatefulWidget {
  const _AudioRecorderSheetContent();

  @override
  State<_AudioRecorderSheetContent> createState() => _AudioRecorderSheetContentState();
}

class _AudioRecorderSheetContentState extends State<_AudioRecorderSheetContent> {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<RecordState>? _recorderStateSub;
  bool _isRecording = false;
  bool _isComplete = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  Uint8List? _recordedBytes;
  int _recordedDuration = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _recorderStateSub?.cancel();
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          AppMessenger.showError(context,
              ErrorMessages.get('chat/audio-permission-denied', L10n.isGreek(context)));
        }
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/nearme_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      ), path: path);

      if (!mounted) return;
      setState(() => _isRecording = true);

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() => _elapsedSeconds = t.tick);
        if (t.tick >= 60) {
          _stopRecording();
          if (mounted) {
            AppMessenger.showInfo(context,
                L10n.localizedMessage(context,
                    'Μέγιστη διάρκεια 60 δευτερόλεπτα / Maximum duration 60 seconds'));
          }
        }
      });

      DebugConfig.log(DebugConfig.chatAudio, 'AudioRecorder: recording started');
    } catch (e, s) {
      DebugConfig.error('AudioRecorder: start failed', data: e, exception: s);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    try {
      _timer?.cancel();
      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        _recordedBytes = bytes;
        _recordedDuration = _elapsedSeconds;
      }

      DebugConfig.log(DebugConfig.chatAudio,
          'AudioRecorder: recording stopped duration=$_elapsedSeconds');
      if (mounted) setState(() => _isComplete = true);
    } catch (e, s) {
      DebugConfig.error('AudioRecorder: stop failed', data: e, exception: s);
    }
  }

  void _cancel() {
    DebugConfig.log(DebugConfig.chatAudio, 'AudioRecorder: cancelled');
    _timer?.cancel();
    if (_isRecording) {
      _recorder.stop();
    }
    Navigator.of(context).pop();
  }

  void _send() {
    if (_recordedBytes == null || _recordedDuration < 1) {
      AppMessenger.showError(context,
          ErrorMessages.get('chat/audio-too-short', L10n.isGreek(context)));
      return;
    }
    DebugConfig.log(DebugConfig.chatAudio,
        'AudioRecorder: sending audio duration=$_recordedDuration');
    Navigator.of(context).pop(AudioRecordResult(
      bytes: _recordedBytes!,
      durationSeconds: _recordedDuration,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = ResponsiveUtils.resolveWidth(context, constraints);
            return SizedBox(
              height: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greek ? '🎤 Ηχογράφηση' : '🎤 Recording',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '$minutes:$seconds',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    onPressed: _isComplete ? null : (_isRecording ? _stopRecording : _startRecording),
                    iconSize: 64,
                    icon: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? Colors.red.withAlpha(200)
                            : theme.colorScheme.primary,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.paddingValueFromWidth(w),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: _cancel,
                          child: Text(greek ? 'Ακύρωση' : 'Cancel'),
                        ),
                        FilledButton(
                          onPressed: _isComplete ? _send : null,
                          child: Text(greek ? 'Αποστολή' : 'Send'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
