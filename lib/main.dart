import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isolate_test/pdf_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render_widgets.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

typedef OnProgressListener = void Function(double completed, double total);
typedef OnResultListener = void Function(String result);

// An encapsulation of a large amount of synchronous processing.
//
// The choice of JSON parsing here is meant as an example that might surface
// in real-world applications.
class Calculator {
  Calculator({
    required this.onProgressListener,
    required this.onResultListener,
    String? data,
  }) :
        // In order to keep the example files smaller, we "cheat" a little and
        // replicate our small json string into a 10,000-element array.
        _data = _replicateJson(data, 100000);

  final OnProgressListener onProgressListener;
  final OnResultListener onResultListener;
  final String _data;
  // This example assumes that the number of objects to parse is known in
  // advance. In a real-world situation, this might not be true; in that case,
  // the app might choose to display an indeterminate progress indicator.
  static const int _NUM_ITEMS = 1000000;
  static const int _NOTIFY_INTERVAL = 1000;

  // Run the computation associated with this Calculator.
  void run() {
    int i = 0;
    final JsonDecoder decoder = JsonDecoder(
      (dynamic key, dynamic value) {
        if (key is int && i++ % _NOTIFY_INTERVAL == 0) {
          onProgressListener(i.toDouble(), _NUM_ITEMS.toDouble());
        }
        return value;
      },
    );
    try {
      final List<dynamic> result = decoder.convert(_data) as List<dynamic>;
      final int n = result.length;

      onResultListener(n.toString());
    } catch (e, stack) {
      print('Invalid JSON file: $e');
      print(stack);
    }
  }

  static String _replicateJson(String? data, int count) {
    final StringBuffer buffer = StringBuffer()..write('[');
    for (int i = 0; i < count; i++) {
      buffer.write(data);
      if (i < count - 1) buffer.write(',');
    }
    buffer.write(']');
    log(buffer.length.toString());

    return buffer.toString();
  }
}

// The current state of the calculation.
enum CalculationState { idle, loading, calculating }

// Structured message to initialize the spawned isolate.
class CalculationMessage {
  CalculationMessage(this.data, this.sendPort);
  String data;
  SendPort sendPort;
}

// A manager for the connection to a spawned isolate.
//
// Isolates communicate with each other via ReceivePorts and SendPorts.
// This class manages these ports and maintains state related to the
// progress of the background computation.
class CalculationManager {
  CalculationManager({
    required this.onProgressListener,
    required this.onResultListener,
  }) : _receivePort = ReceivePort() {
    _receivePort.listen(_handleMessage);
  }

  CalculationState _state = CalculationState.idle;
  CalculationState get state => _state;
  bool get isRunning => _state != CalculationState.idle;

  double _completed = 0.0;
  double _total = 1.0;

  final OnProgressListener onProgressListener;
  final OnResultListener onResultListener;

  // Start the background computation.
  //
  // Does nothing if the computation is already running.
  void start() {
    if (!isRunning) {
      _state = CalculationState.loading;
      _runCalculation();
    }
  }

  // Stop the background computation.
  //
  // Kills the isolate immediately, if spawned. Does nothing if the
  // computation is not running.
  void stop() {
    if (isRunning) {
      _state = CalculationState.idle;
      if (_isolate != null) {
        _isolate!.kill(priority: Isolate.immediate);
        _isolate = null;
        _completed = 0.0;
        _total = 1.0;
        // _receivePort.close();
      }
    }
  }

  final ReceivePort _receivePort;
  Isolate? _isolate;

  void _runCalculation() {
    // Load the JSON string. This is done in the main isolate because spawned
    // isolates do not have access to the root bundle. However, the loading
    // process is asynchronous, so the UI will not block while the file is
    // loaded.
    rootBundle.loadString('assets/data.json').then<void>((String data) {
      if (isRunning) {
        final CalculationMessage message =
            CalculationMessage(data, _receivePort.sendPort);
        // Spawn an isolate to JSON-parse the file contents. The JSON parsing
        // is synchronous, so if done in the main isolate, the UI would block.
        Isolate.spawn<CalculationMessage>(_calculate, message)
            .then((Isolate isolate) {
          if (!isRunning) {
            isolate.kill(priority: Isolate.immediate);
          } else {
            _state = CalculationState.calculating;
            _isolate = isolate;
          }
        });
      }
    });
  }

  void _handleMessage(dynamic message) {
    if (message is List<double>) {
      _completed = message[0];
      _total = message[1];
      onProgressListener(_completed, _total);
    } else if (message is String) {
      _completed = 0.0;
      _total = 1.0;
      _isolate = null;
      _state = CalculationState.idle;
      onResultListener(message);
    }
  }

  // Main entry point for the spawned isolate.
  //
  // This entry point must be static, and its (single) argument must match
  // the message passed in Isolate.spawn above. Typically, some part of the
  // message will contain a SendPort so that the spawned isolate can
  // communicate back to the main isolate.
  //
  // Static and global variables are initialized anew in the spawned isolate,
  // in a separate memory space.
  static void _calculate(CalculationMessage message) {
    final SendPort sender = message.sendPort;
    final Calculator calculator = Calculator(
      onProgressListener: (double completed, double total) {
        sender.send(<double>[completed, total]);
      },
      onResultListener: sender.send,
      data: message.data,
    );
    calculator.run();
  }
}

// Main app widget.
//
// The app shows a simple UI that allows control of the background computation,
// as well as an animation to illustrate that the UI does not block while this
// computation is performed.
//
// This is a StatefulWidget in order to hold the CalculationManager and
// the AnimationController for the running animation.
class IsolateExampleWidget extends StatefulWidget {
  const IsolateExampleWidget({Key? key}) : super(key: key);

  @override
  IsolateExampleState createState() => IsolateExampleState();
}

// Main application state.
class IsolateExampleState extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  String _status = 'Idle';
  String _label = 'Start';
  String _result = ' ';
  late final AnimationController _animation = AnimationController(
    duration: const Duration(milliseconds: 3600),
    vsync: this,
  )..repeat();

  late final PdfGeneratorManager pdfGeneratorManager = PdfGeneratorManager(
    directoryPath: '/data/user/0/com.example.isolate_test/cache',
    documentName: '123',
    onPdfSaved: _handleResult,
  );

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          RotationTransition(
            turns: _animation,
            child: Container(
              width: 120.0,
              height: 120.0,
              color: const Color(0xFF882222),
            ),
          ),
          Text(_status),
          Center(
            child: ElevatedButton(
              onPressed: _handleButtonPressed,
              child: Text(_label),
            ),
          ),
          Text(_result),
        ],
      ),
    );
  }

  void _handleResult(String result) {
    /* getTemporaryDirectory().then((dir) {
      final File file = File('${dir.path}/heh.json');
      file.writeAsString(result);
    }); */
    _updateState(result);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return PdfView(
            filePath: result,
          );
        },
      ),
    );
  }

  void _handleButtonPressed() {
    if (pdfGeneratorManager.isRunning)
      pdfGeneratorManager.stop();
    else
      pdfGeneratorManager.start();
    _updateState(' ');
  }

  String _getStatus(PdfGeneratorState state) {
    switch (state) {
      case PdfGeneratorState.generating:
        return 'In Progress';
      case PdfGeneratorState.idle:
      default:
        return 'Idle';
    }
  }

  void _updateState(String result) {
    setState(() {
      _result = result;
      _label = pdfGeneratorManager.isRunning ? 'Stop' : 'Start';
      _status = _getStatus(pdfGeneratorManager.state);
    });
  }
}

void main() {
  runApp(const MaterialApp(
    showPerformanceOverlay: true,
    home: IsolateExampleWidget(),
  ));
}

class PdfView extends StatelessWidget {
  const PdfView({
    Key? key,
    required this.filePath,
  }) : super(key: key);

  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PdfViewer.openFile(
        filePath,
        params: PdfViewerParams(
          onViewerControllerInitialized: (controller) {
            print(controller?.ready?.pageCount);
          },
          padding: 20,
          pageDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0.0, 3.0),
              )
            ],
          ),
        ),
      ),
    );
  }
}
