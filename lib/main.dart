import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:neworion_pdf_editor_lite/neworion_pdf_editor_lite.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _pdfFile;
  bool laoding = false;

  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _editPDF() async {
    if (_pdfFile == null) return;
    setState(() {
      laoding = true;
    });

    File? editedFile = await OPdf.openEditor(context, _pdfFile!);
    setState(() {
      _pdfFile = null;
    });
    if (editedFile != null) {
      setState(() {
        _pdfFile = editedFile;
      });
    }
    setState(() {
      laoding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Editor')),
      body: Column(
        children: [
          ElevatedButton(onPressed: _pickPDF, child: const Text('Pick PDF')),
          ElevatedButton(
            onPressed: _editPDF,
            child: const Text('Add Text to PDF'),
          ),
          laoding
              ? CircularProgressIndicator()
              : Expanded(
                child:
                    _pdfFile == null
                        ? const Center(child: Text('No PDF selected'))
                        : PDFView(filePath: _pdfFile!.path),
              ),
        ],
      ),
    );
  }
}
