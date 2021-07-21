import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

typedef OnPdfSaved = void Function(String filePath);

typedef DocumentGenerator = FutureOr<String?> Function(
  String directoryPath,
  dynamic data,
);

class _PdfGeneratorMessage {
  _PdfGeneratorMessage({
    required this.directoryPath,
    required this.documentGenerator,
    required this.sendPort,
    this.data,
  });

  final String directoryPath;

  final DocumentGenerator documentGenerator;

  final dynamic data;

  final SendPort sendPort;
}

enum PdfGeneratorState { idle, generating }

class PdfGenerator {
  PdfGenerator({
    OnPdfSaved? onPdfSaved,
  })  : _onPdfSaved = onPdfSaved,
        _resultPort = ReceivePort(),
        _errorPort = ReceivePort() {
    _resultPort.listen(_handleResult);
    _errorPort.listen(_handleError);
  }

  OnPdfSaved? _onPdfSaved;

  PdfGeneratorState _state = PdfGeneratorState.idle;

  PdfGeneratorState get state => _state;

  bool get isRunning => _state != PdfGeneratorState.idle;

  void start({
    required DocumentGenerator documentGenerator,
    required String directoryPath,
    dynamic data,
  }) {
    if (!isRunning) {
      _state = PdfGeneratorState.generating;
      _runGenerator(
        documentGenerator: documentGenerator,
        directoryPath: directoryPath,
        data: data,
      );
    }
  }

  void stop() {
    if (isRunning) {
      _state = PdfGeneratorState.idle;
      if (_isolate != null) {
        _isolate!.kill(priority: Isolate.immediate);
        _isolate = null;
      }
    }
  }

  void dispose() {
    _onPdfSaved = null;
    _state = PdfGeneratorState.idle;
    _resultPort.close();
    _errorPort.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  final ReceivePort _resultPort;
  final ReceivePort _errorPort;

  Isolate? _isolate;

  void _runGenerator({
    required DocumentGenerator documentGenerator,
    required String directoryPath,
    dynamic data,
  }) {
    final _PdfGeneratorMessage message = _PdfGeneratorMessage(
      directoryPath: directoryPath,
      documentGenerator: documentGenerator,
      sendPort: _resultPort.sendPort,
      data: data,
    );

    Isolate.spawn<_PdfGeneratorMessage>(
      _run,
      message,
      onError: _errorPort.sendPort,
    ).then((Isolate isolate) {
      if (!isRunning) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    });
  }

  void _handleResult(dynamic result) {
    if (result is String) {
      _state = PdfGeneratorState.idle;
      _onPdfSaved?.call(result);
    }
  }

  void _handleError(dynamic error) {
    log('$error');
  }

  static Future<void> _run(_PdfGeneratorMessage message) async {
    final SendPort sender = message.sendPort;

    final path = await message.documentGenerator(
      message.directoryPath,
      message.data,
    );

    sender.send(path);
  }
}
