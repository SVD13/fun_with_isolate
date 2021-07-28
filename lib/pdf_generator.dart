import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

typedef OnPdfSaved = void Function(String filePath);
typedef OnPdfGeneratorError = void Function(dynamic error);

typedef DocumentGenerator<T> = FutureOr<String> Function(
  String directoryPath,
  T data,
);

class _PdfGeneratorMessage<T> {
  _PdfGeneratorMessage({
    required this.directoryPath,
    required this.documentGenerator,
    required this.sendPort,
    required this.data,
  });

  final String directoryPath;

  final DocumentGenerator<T> documentGenerator;

  final T data;

  final SendPort sendPort;

  FutureOr<String> apply() => documentGenerator(directoryPath, data);
}

enum PdfGeneratorState { idle, generating }

class PdfGenerator {
  /* PdfGenerator({
    OnPdfSaved? onPdfSaved,
    OnPdfGeneratorError? onPdfGeneratorError,
  });
   : _onPdfSaved = onPdfSaved,
        _onPdfGeneratorError =
            onPdfGeneratorError ,
         _resultPort = ReceivePort(),
        _errorPort = ReceivePort(),
        _onExitPort = ReceivePort() 
  {
     _resultPort.listen(_handleResult);
    _errorPort.listen(_handleError);
    _exitPort.listen((message) {
      log('$message');
    }); 
  }*/

  /* OnPdfSaved? _onPdfSaved;

  OnPdfGeneratorError? _onPdfGeneratorError; */

  PdfGeneratorState _state = PdfGeneratorState.idle;

  PdfGeneratorState get state => _state;

  bool get isRunning => _state != PdfGeneratorState.idle;

  Future<String> run<T>({
    required DocumentGenerator<T> documentGenerator,
    required String directoryPath,
    required T data,
  }) async {
    _state = PdfGeneratorState.generating;

    if (!isRunning) {
      return _run(
        documentGenerator: documentGenerator,
        directoryPath: directoryPath,
        data: data,
      );
    }

    if (_isolate != null) {
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }

    return _run(
      documentGenerator: documentGenerator,
      directoryPath: directoryPath,
      data: data,
    );
  }

  void cancel() {
    if (isRunning) {
      _state = PdfGeneratorState.idle;
      if (_isolate != null) {
        _isolate!.kill(priority: Isolate.immediate);
        _isolate = null;
      }
    }
  }

  void dispose() {
    // _onPdfSaved = null;

    _state = PdfGeneratorState.idle;

    _resultPort?.close();
    _errorPort?.close();
    _exitPort?.close();

    _resultPort = null;
    _errorPort = null;
    _exitPort = null;

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  ReceivePort? _resultPort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;

  Isolate? _isolate;

  Future<String> _run<T>({
    required DocumentGenerator<T> documentGenerator,
    required String directoryPath,
    required T data,
  }) async {
    log('_run');
    _resultPort = ReceivePort();
    _errorPort = ReceivePort();
    _exitPort = ReceivePort();

    _isolate = await Isolate.spawn<_PdfGeneratorMessage<T>>(
      _spawn,
      _PdfGeneratorMessage<T>(
        directoryPath: directoryPath,
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

    final Completer<String> result = Completer<String>();

    _resultPort!.listen((resultData) {
      log('_resultPort message: $resultData');
      assert(resultData == null || resultData is String);
      if (!result.isCompleted) result.complete(resultData as String);
    });

    _errorPort!.listen((errorData) {
      log('_errorPort message: $errorData');
      result.completeError(errorData);
      /* assert(errorData is List<dynamic>);
      assert(errorData.length == 2);
      final Exception exception = Exception(errorData[0]);
      final StackTrace stack = StackTrace.fromString(errorData[1] as String);
      if (result.isCompleted) {
        Zone.current.handleUncaughtError(exception, stack);
      } else {
        result.completeError(exception, stack);
      } */
    });

    _exitPort!.listen((exitData) {
      log('_exitPort message: $exitData');
      if (!result.isCompleted) {
        result.completeError(
          Exception('Isolate exited without result or error.'),
        );
      }
    });

    await result.future;

    _state = PdfGeneratorState.idle;
    log('$_state');
    _resultPort!.close();
    _errorPort!.close();
    _exitPort!.close();
    _isolate!.kill();

    return result.future;
  }

  /* void _handleResult(dynamic result) {
    if (result is String) {
      _state = PdfGeneratorState.idle;
      _onPdfSaved?.call(result);
    }
  }

  void _handleError(dynamic error) {
    _state = PdfGeneratorState.idle;
    _onPdfGeneratorError?.call(error);
  } */

  static Future<void> _spawn<T>(_PdfGeneratorMessage<T> message) async {
    log('_spawn');

    final SendPort sender = message.sendPort;
    final path = await message.apply();

    sender.send(path);
  }
}
