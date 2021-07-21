import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isolate_test/pdf_generator.dart';
import 'package:isolate_test/pdf_review.dart';
import 'package:isolate_test/pdf_templates.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MaterialApp(
    showPerformanceOverlay: true,
    home: Root(),
  ));
}

class Root extends StatefulWidget {
  const Root({Key? key}) : super(key: key);

  @override
  RootState createState() => RootState();
}

class RootState extends State<Root> with SingleTickerProviderStateMixin {
  String _status = 'Idle';
  String _label = 'Start';
  String _result = ' ';
  late final AnimationController _animation = AnimationController(
    duration: const Duration(milliseconds: 3600),
    vsync: this,
  )..repeat();

  late final PdfGenerator pdfGeneratorManager = PdfGenerator(
    onPdfSaved: _handleResult,
  );

  @override
  void dispose() {
    _animation.dispose();
    pdfGeneratorManager.dispose();
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
    log(result);

    _updateState(result);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return PdfReview(
            filePath: result,
          );
        },
      ),
    );
  }

  void _handleButtonPressed() {
    if (pdfGeneratorManager.isRunning) {
      pdfGeneratorManager.stop();
      _updateState(' ');
    } else {
      rootBundle.load('assets/tomato.png').then(
        (data) async {
          final path = (await getTemporaryDirectory()).path;
          pdfGeneratorManager.start(
            documentGenerator: generatePDF,
            directoryPath: path,
            images: {'tomato': data.buffer.asUint8List()},
          );
          _updateState(' ');
        },
      );
    }
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
