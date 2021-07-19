import 'dart:io';
import 'dart:isolate';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

typedef OnPdfSaved = void Function(String filePath);

class PdfGeneratorMessage {
  PdfGeneratorMessage({
    required this.directoryPath,
    required this.documentName,
    required this.document,
    required this.sendPort,
  });

  final String directoryPath;

  final String documentName;

  final pw.Document document;

  final SendPort sendPort;
}

class PdfGenerator {
  PdfGenerator({
    required this.directoryPath,
    required this.documentName,
    required this.document,
    required this.onPdfSaved,
  });

  final String directoryPath;

  final String documentName;

  final pw.Document document;

  final OnPdfSaved onPdfSaved;

  void run() async {
    final filePath = '$directoryPath/$documentName.pdf';
    final file = File(filePath);
    final bytes = await document.save();
    file.writeAsBytesSync(bytes);
    onPdfSaved(filePath);
  }
}

class PdfGeneratorManager {}
