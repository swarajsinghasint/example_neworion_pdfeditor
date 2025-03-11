import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class OPdfEditScreen extends StatefulWidget {
  final File pdfFile;

  const OPdfEditScreen({super.key, required this.pdfFile});

  @override
  State<OPdfEditScreen> createState() => _OPdfEditScreenState();
}

class _OPdfEditScreenState extends State<OPdfEditScreen> {
  late final PdfViewerController _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  Future<void> _saveHighlightedPdf() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save functionality coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('PDF Editor'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _saveHighlightedPdf,
            icon: const Icon(Icons.save),
            tooltip: 'Save PDF',
          ),
        ],
      ),
      body: SfPdfViewer.file(
        widget.pdfFile,
        controller: _pdfViewerController,
        pageLayoutMode: PdfPageLayoutMode.single, // Enables left-right swipe
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.grey[900],
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(Icons.edit, "Draw"),
            _buildBottomNavItem(Icons.text_fields, "Add Text"),
            _buildBottomNavItem(Icons.highlight, "Highlight"),
            _buildBottomNavItem(Icons.format_underlined, "Underline"),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label) {
    return InkWell(
      onTap: () {}, // You can implement functionality later
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
