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
    required this.sendPort,
  });

  final String directoryPath;

  final String documentName;

  final SendPort sendPort;
}

class PdfGenerator {
  PdfGenerator({
    required this.directoryPath,
    required this.documentName,
    required this.onPdfSaved,
  });

  final String directoryPath;

  final String documentName;

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

    document.addPage(
      pw.MultiPage(
        maxPages: 10000,
        build: (context) => [
          pw.Table.fromTextArray(
            border: null,
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              color: PdfColor.fromInt(0xff00ff00),
            ),
            headerHeight: 25,
            cellHeight: 40,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
            },
            headerStyle: pw.TextStyle(
              color: PdfColor.fromInt(0xffffffff),
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            columnWidths: {
              0: const pw.IntrinsicColumnWidth(flex: 1),
              1: const pw.IntrinsicColumnWidth(flex: 2),
              2: const pw.IntrinsicColumnWidth(flex: 5),
              3: const pw.IntrinsicColumnWidth(flex: 4),
              4: const pw.IntrinsicColumnWidth(flex: 4),
            },
            cellStyle: const pw.TextStyle(
              color: PdfColor.fromInt(0xff000000),
              fontSize: 10,
            ),
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColor.fromInt(0xff000000),
                  width: .5,
                ),
              ),
            ),
            headers: List<String>.generate(
              ['SKU#', 'Item Description', 'Price', 'Quantity', 'Total'].length,
              (col) => [
                'SKU#',
                'Item Description',
                'Price',
                'Quantity',
                'Total'
              ][col],
            ),
            data: List<List<String>>.generate(
              1000,
              (row) => List<String>.generate(
                ['SKU#', 'Item Description', 'Price', 'Quantity', 'Total']
                    .length,
                (col) => '$row-$col',
              ),
            ),
          ),
        ],
      ),
    );

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
    required this.onPdfSaved,
  }) : _receivePort = ReceivePort() {
    _receivePort.listen(_handleMessage);
  }

  PdfGeneratorState _state = PdfGeneratorState.idle;

  PdfGeneratorState get state => _state;

  bool get isRunning => _state != PdfGeneratorState.idle;

  final String directoryPath;

  final String documentName;

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
      onPdfSaved: sender.send,
    );
    pdfGenerator.run();
  }
}
