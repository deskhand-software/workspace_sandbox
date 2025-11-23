import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/workspace_process.dart';

class NativeProcessImpl implements WorkspaceProcess {
  final Process _process;
  final _stdoutCtrl = StreamController<String>();
  final _stderrCtrl = StreamController<String>();
  final _exitCodeCompleter = Completer<int>();

  Timer? _timeoutTimer;
  bool _isCancelled = false;

  NativeProcessImpl(this._process, {Duration? timeout}) {
    // FIX: Usar allowMalformed: true para evitar crashes con output de Windows (ANSI/CP850)
    const decoder = Utf8Decoder(allowMalformed: true);

    _process.stdout.transform(decoder).listen((data) => _stdoutCtrl.add(data),
        onDone: () => _stdoutCtrl.close(),
        onError: (e) {
          // Capturamos errores de stream por si acaso
          _stdoutCtrl.add('[Stream Error: $e]');
        });

    _process.stderr.transform(decoder).listen((data) => _stderrCtrl.add(data),
        onDone: () => _stderrCtrl.close(),
        onError: (e) {
          _stderrCtrl.add('[Stream Error: $e]');
        });

    _process.exitCode.then((code) {
      if (!_exitCodeCompleter.isCompleted) {
        _exitCodeCompleter.complete(code);
      }
      _timeoutTimer?.cancel();
    });

    if (timeout != null) {
      _timeoutTimer = Timer(timeout, () {
        kill();
        if (!_stderrCtrl.isClosed) {
          _stderrCtrl.add('\n[timeout]\n');
        }
      });
    }
  }

  @override
  Stream<String> get stdout => _stdoutCtrl.stream;

  @override
  Stream<String> get stderr => _stderrCtrl.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  bool get isCancelled => _isCancelled;

  @override
  void kill() {
    if (_isCancelled) return;
    _isCancelled = true;

    _process.kill(ProcessSignal.sigterm);

    Timer(const Duration(milliseconds: 250), () {
      _process.kill(ProcessSignal.sigkill);
    });
  }
}
