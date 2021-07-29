import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

import 'dart:typed_data';

class PdfGeneratorInput<T> {
  PdfGeneratorInput({
    required this.path,
    required this.images,
    this.data,
  });

  final String path;
  final Map<String, Uint8List> images;
  final T? data;
}

typedef DocumentGenerator<T> = FutureOr<String> Function(
  PdfGeneratorInput<T> data,
);

class _PdfGeneratorMessage<T> {
  _PdfGeneratorMessage({
    required this.documentGenerator,
    required this.sendPort,
    required this.data,
  });

  final DocumentGenerator<T> documentGenerator;

  final PdfGeneratorInput<T> data;

  final SendPort sendPort;

  FutureOr<String> apply() => documentGenerator(data);
}

enum PdfGeneratorState { idle, generating }

class PdfGenerator {
  bool get isRunning => _isRunning;
  bool _isRunning = false;

  Future<String> run<T>({
    required DocumentGenerator<T> documentGenerator,
    required PdfGeneratorInput<T> data,
  }) async {
    if (isRunning) throw Exception('PdfGenerator already runs.');

    _isRunning = true;
    return _run(
      documentGenerator: documentGenerator,
      data: data,
    );
  }

  void cancel() {
    _isRunning = false;
    if (_isolate != null) {
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;

    _isRunning = false;

    _resultPort?.close();
    _errorPort?.close();
    _exitPort?.close();

    _resultPort = null;
    _errorPort = null;
    _exitPort = null;
  }

  ReceivePort? _resultPort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;

  Isolate? _isolate;

  Future<String> _run<T>({
    required DocumentGenerator<T> documentGenerator,
    required PdfGeneratorInput<T> data,
  }) async {
    log('_run');
    _resultPort = ReceivePort();
    _errorPort = ReceivePort();
    _exitPort = ReceivePort();

    _isolate = await Isolate.spawn<_PdfGeneratorMessage<T>>(
      _spawn,
      _PdfGeneratorMessage<T>(
        documentGenerator: documentGenerator,
        sendPort: _resultPort!.sendPort,
        data: data,
      ),
      onError: _errorPort!.sendPort,
      onExit: _exitPort!.sendPort,
    );

    if (!isRunning) {
      _isolate?.kill(priority: Isolate.immediate);
    }

    final Completer<String> completer = Completer<String>();

    _resultPort!.listen((resultData) {
      assert(resultData == null || resultData is String);
      if (!completer.isCompleted) completer.complete(resultData as String);
    });

    _errorPort!.listen((errorData) {
      cancel();

      assert(errorData is List<dynamic>);
      assert(errorData.length == 2);
      final Exception exception = Exception(errorData[0]);
      final StackTrace stack = StackTrace.fromString(errorData[1] as String);
      if (completer.isCompleted) {
        Zone.current.handleUncaughtError(exception, stack);
      } else {
        completer.completeError(exception, stack);
      }
    });

    _exitPort!.listen((exitData) {
      cancel();

      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Isolate exited without result or error.'),
        );
      }
    });

    await completer.future;

    _isRunning = false;
    _resultPort!.close();
    _errorPort!.close();
    _exitPort!.close();
    _isolate!.kill();

    return completer.future;
  }

  static Future<void> _spawn<T>(_PdfGeneratorMessage<T> message) async {
    log('_spawn');

    final SendPort sender = message.sendPort;
    final path = await message.apply();

    sender.send(path);
  }
}
