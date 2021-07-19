import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

typedef OnPdfSaved = void Function(String filePath);

class PdfGeneratorMessage {
  PdfGeneratorMessage({
    required this.directoryPath,
    required this.documentName,
    required this.pages,
    required this.sendPort,
  });

  final String directoryPath;

  final String documentName;

  final List<pw.Page> pages;

  final SendPort sendPort;
}

class PdfGenerator {
  PdfGenerator({
    required this.directoryPath,
    required this.documentName,
    required this.pages,
    required this.onPdfSaved,
  });

  final String directoryPath;

  final String documentName;

  final List<pw.Page> pages;

  final OnPdfSaved onPdfSaved;

  void run() async {
    final document = pw.Document(
      version: PdfVersion.pdf_1_5,
    );

    const tableHeaders = [
      'SKU#',
      'Item Description',
      'Price',
      'Quantity',
      'Total'
    ];

    for (final page in pages) {
      document.addPage(page);
    }

    final filePath = '$directoryPath/$documentName.pdf';
    final file = File(filePath);
    final bytes = await document.save();
    file.writeAsBytesSync(bytes);
    onPdfSaved(filePath);
  }
}

enum PdfGeneratorState { idle, generating }

class PdfGeneratorManager {
  PdfGeneratorManager({
    required this.directoryPath,
    required this.documentName,
    required this.pages,
    required this.onPdfSaved,
  }) : _receivePort = ReceivePort() {
    _receivePort.listen(_handleMessage);
  }

  PdfGeneratorState _state = PdfGeneratorState.idle;

  PdfGeneratorState get state => _state;

  bool get isRunning => _state != PdfGeneratorState.idle;

  final String directoryPath;

  final String documentName;

  final List<pw.Page> pages;

  final OnPdfSaved onPdfSaved;

  void start() {
    if (!isRunning) {
      _state = PdfGeneratorState.generating;
      _runGenerator();
    }
  }

  void stop() {
    if (isRunning) {
      _state = PdfGeneratorState.idle;
      if (_isolate != null) {
        _isolate!.kill(priority: Isolate.immediate);
        _isolate = null;
        // _receivePort.close();
      }
    }
  }

  final ReceivePort _receivePort;
  Isolate? _isolate;

  void _runGenerator() {
    final PdfGeneratorMessage message = PdfGeneratorMessage(
      directoryPath: directoryPath,
      documentName: documentName,
      pages: pages,
      sendPort: _receivePort.sendPort,
    );

    Isolate.spawn<PdfGeneratorMessage>(
      _calculate,
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
      onPdfSaved(message);
      log(message);
    }
  }

  static void _calculate(PdfGeneratorMessage message) {
    final SendPort sender = message.sendPort;
    final PdfGenerator pdfGenerator = PdfGenerator(
      directoryPath: message.directoryPath,
      documentName: message.documentName,
      pages: message.pages,
      onPdfSaved: sender.send,
    );
    pdfGenerator.run();
  }
}
