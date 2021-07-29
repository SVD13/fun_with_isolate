import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isolate_test/pdf_generator.dart';
import 'package:isolate_test/pdf_review.dart';
import 'package:isolate_test/pdf_templates.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MaterialApp(
    showPerformanceOverlay: true,
    home: Root(),
    onGenerateRoute: (settings) {
      switch (settings.name) {
        case '/':
          return MaterialPageRoute(
            builder: (context) {
              return const Root();
            },
          );

        case '/view':
          return MaterialPageRoute(
            builder: (context) {
              return PdfReview(
                filePath: settings.arguments as String,
              );
            },
          );
      }
    },
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
    duration: const Duration(milliseconds: 1500),
    vsync: this,
  )..repeat();

  late final PdfGenerator pdfGeneratorManager = PdfGenerator();

  @override
  void dispose() {
    _animation.dispose();
    // pdfGeneratorManager.dispose();
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
          Center(
            child: ElevatedButton(
              onPressed: () {
                pdfGeneratorManager.cancel();
              },
              child: Text('Stop'),
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
    Navigator.pushNamed(
      context,
      '/view',
      arguments: result,
    );
  }

  Future<void> _handleButtonPressed() async {
    setState(() {
      _status = 'In Progress';
    });

    final logoBytes =
        (await rootBundle.load('assets/tomato.png')).buffer.asUint8List();

    final path = (await getTemporaryDirectory()).path;

    final filePath = await pdfGeneratorManager.run(
      documentGenerator: generatePDF,
      data: PdfGeneratorInput(
        path: path,
        images: {'tomato': logoBytes},
        data: 'asdasd',
      ),
    );

    /* final filePath = await compute(
      generatePDF,
      PdfData('path', {'tomato': logoBytes}),
    ); */

    _handleResult(filePath);
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
      _status = 'Idle';
    });
  }
}
