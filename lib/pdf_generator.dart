import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

typedef OnPdfSaved = void Function(String filePath);

typedef DocumentGenerator = FutureOr<String> Function(
  String,
  Map<String, Uint8List>,
);

class _PdfGeneratorMessage {
  _PdfGeneratorMessage({
    required this.directoryPath,
    required this.documentGenerator,
    required this.images,
    required this.sendPort,
  });

  final String directoryPath;

  final DocumentGenerator documentGenerator;

  final Map<String, Uint8List> images;

  final SendPort sendPort;
}

enum PdfGeneratorState { idle, generating }

class PdfGenerator {
  PdfGenerator({
    OnPdfSaved? onPdfSaved,
  })  : _onPdfSaved = onPdfSaved,
        _receivePort = ReceivePort() {
    _receivePort.listen(_handleMessage);
  }

  OnPdfSaved? _onPdfSaved;

  PdfGeneratorState _state = PdfGeneratorState.idle;

  PdfGeneratorState get state => _state;

  bool get isRunning => _state != PdfGeneratorState.idle;

  void start({
    required DocumentGenerator documentGenerator,
    required String directoryPath,
    Map<String, Uint8List> images = const {},
  }) {
    if (!isRunning) {
      _state = PdfGeneratorState.generating;
      _runGenerator(
        documentGenerator: documentGenerator,
        directoryPath: directoryPath,
        images: images,
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
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort.close();
  }

  final ReceivePort _receivePort;
  Isolate? _isolate;

  void _runGenerator({
    required DocumentGenerator documentGenerator,
    required String directoryPath,
    required Map<String, Uint8List> images,
  }) {
    final _PdfGeneratorMessage message = _PdfGeneratorMessage(
      directoryPath: directoryPath,
      documentGenerator: documentGenerator,
      sendPort: _receivePort.sendPort,
      images: images,
    );

    Isolate.spawn<_PdfGeneratorMessage>(
      _run,
      message,
    ).then((Isolate isolate) {
      if (!isRunning) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    });
  }

  void _handleMessage(dynamic message) {
    if (message is String) {
      _state = PdfGeneratorState.idle;
      _onPdfSaved?.call(message);
    }
  }

  static Future<void> _run(_PdfGeneratorMessage message) async {
    final SendPort sender = message.sendPort;

    final path = await message.documentGenerator(
      message.directoryPath,
      message.images,
    );

    sender.send(path);
  }
}
