import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

typedef OnPdfSaved = void Function(String filePath);

typedef DocumentGenerator = FutureOr<String> Function(Map<String, Uint8List>);

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
    required this.onPdfSaved,
  }) : _receivePort = ReceivePort() {
    _receivePort.listen(_handleMessage);
  }

  PdfGeneratorState _state = PdfGeneratorState.idle;

  PdfGeneratorState get state => _state;

  bool get isRunning => _state != PdfGeneratorState.idle;

  final OnPdfSaved onPdfSaved;

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
        // _receivePort.close();
      }
    }
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
      onPdfSaved(message);
    }
  }

  static Future<void> _run(_PdfGeneratorMessage message) async {
    final SendPort sender = message.sendPort;

    final path = await message.documentGenerator(message.images);

    sender.send(path);
  }
}

Future<String> generatePDF(Map<String, Uint8List> images) async {
  log('_generatePDFInIsolate: start');
  final document = pw.Document(
    version: PdfVersion.pdf_1_5,
  );

  final image = pw.MemoryImage(
    images['tomato']!,
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
        pw.Image(image, width: 110, height: 110),
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
            0: const pw.IntrinsicColumnWidth(flex: 2),
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
            tableHeaders.length,
            (col) => tableHeaders[col],
          ),
          data: List<List<String>>.generate(
            1200,
            (row) => List<String>.generate(
              tableHeaders.length,
              (col) => '$row-$col',
            ),
          ),
        ),
      ],
    ),
  );
  final bytes = await document.save();
  log('_generatePDFInIsolate: bytes generated');

  final filePath = '/data/user/0/com.example.isolate_test/cache/12345.pdf';
  final file = File(filePath);

  file.writeAsBytesSync(bytes);
  log('_generatePDFInIsolate: wrote on disk');

  return filePath;
}

/* Future<Uint8List> generatePDF() async {
  //Creating isolate to process PNG to PDF conversion.
  final _docData = await compute<int, Uint8List>(generatePDFInIsolate, 1);

  return _docData; //Document as`Uint8List`
} */
