import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:printing/printing.dart';

class PdfReview extends StatefulWidget {
  const PdfReview({
    Key? key,
    required this.filePath,
  }) : super(key: key);

  final String filePath;

  @override
  _PdfReviewState createState() => _PdfReviewState();
}

class _PdfReviewState extends State<PdfReview> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () async {
              final file = File(widget.filePath);
              final bytes = await file.readAsBytes();
              Printing.layoutPdf(
                onLayout: (_) => bytes,
                dynamicLayout: false,
              );
            },
            icon: Icon(Icons.print_outlined),
          ),
          IconButton(
            onPressed: () async {
              final file = File(widget.filePath);
              final bytes = await file.readAsBytes();
              Printing.sharePdf(
                bytes: bytes,
                filename: 'heh.pdf',
              );
            },
            icon: Icon(Icons.share_outlined),
          )
        ],
      ),
      body: PdfViewer.openFile(
        widget.filePath,
        params: PdfViewerParams(
          onViewerControllerInitialized: (controller) {
            print(controller?.ready?.pageCount);
          },
          maxScale: 3.0,
          minScale: 1.0,
          padding: 20,
          pageDecoration: BoxDecoration(
            color: Colors.white,
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
