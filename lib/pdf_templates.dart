import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<String> generatePDF(
  String directoryPath,
  Map<String, Uint8List> images,
) async {
  log('generatePDF: start');
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
      maxPages: 2000,
      build: (context) => [
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Image(image, width: 110, height: 110),
        ),
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
            100,
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
  log('generatePDF: bytes generated');

  final filePath = '$directoryPath/heh.pdf';
  final file = File(filePath);

  file.writeAsBytesSync(bytes);
  log('generatePDF: wrote on disk');

  return filePath;
}
