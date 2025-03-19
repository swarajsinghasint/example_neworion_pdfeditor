import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class OPdfEditScreen extends StatefulWidget {
  final File pdfFile;

  const OPdfEditScreen({super.key, required this.pdfFile});

  @override
  State<OPdfEditScreen> createState() => _OPdfEditScreenState();
}

class _OPdfEditScreenState extends State<OPdfEditScreen> {
  late final PdfViewerController _pdfViewerController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  int _selectedIndex = -1;
  int _currentPage = 1;
  int _totalPages = 1;
  List<Offset?> _points = [];
  bool _isDrawing = false;
  bool _isPageLoaded = false;
  final DrawingController _drawingController = DrawingController();

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _currentPage--;
      _pdfViewerController.previousPage();
      _points.clear(); // Clear drawing when page changes
      setState(() {});
    }
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages) {
      _currentPage++;
      _pdfViewerController.nextPage();
      _points.clear(); // Clear drawing when page changes
      setState(() {});
    }
  }

  void _selectColor() async {
    Color selectedColor = await _showColorPicker(context);
    _drawingController.setColor(selectedColor);
    setState(() {});
  }

  Future<Color> _showColorPicker(BuildContext context) async {
    Color pickedColor = _drawingController._currentColor;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: pickedColor,
              onColorChanged: (color) {
                pickedColor = color;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
    return pickedColor;
  }

  Future<void> _saveDrawing() async {
    try {
      final pdfDoc = PdfDocument(
        inputBytes: await widget.pdfFile.readAsBytes(),
      );

      for (int i = 0; i < _totalPages; i++) {
        // Switch page and set drawing for the current page
        _drawingController.setPage(i + 1);

        // Delay to allow page change to complete
        await Future.delayed(const Duration(milliseconds: 200));

        ByteData? imageData = await _drawingController.getImageData(i + 1);
        if (imageData != null) {
          PdfPage page = pdfDoc.pages[i];
          final PdfImage image = PdfBitmap(imageData.buffer.asUint8List());

          // Get page dimensions
          final double pageWidth = page.getClientSize().width;
          final double pageHeight = page.getClientSize().height;

          // Draw the captured image on the respective page
          page.graphics.drawImage(
            image,
            Rect.fromLTWH(0, 0, pageWidth, pageHeight),
          );
        }
      }

      // Save updated PDF
      final output = await getTemporaryDirectory();
      final savedPath = '${output.path}/edited.pdf';
      final file = File(savedPath);
      await file.writeAsBytes(await pdfDoc.save());
      pdfDoc.dispose();

      // Open the saved PDF
      OpenFile.open(savedPath);
    } catch (e) {
      debugPrint('Error while saving drawing: $e');
    }
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
            onPressed: _saveDrawing,
            icon: const Icon(Icons.save),
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.width * 1.414,
            width: MediaQuery.of(context).size.width,
            child: Stack(
              children: [
                SfPdfViewer.file(
                  key: _pdfViewerKey,
                  widget.pdfFile,
                  controller: _pdfViewerController,
                  pageLayoutMode: PdfPageLayoutMode.single,
                  scrollDirection: PdfScrollDirection.horizontal,
                  canShowScrollHead: false,
                  canShowPaginationDialog: false,
                  canShowTextSelectionMenu: false,
                  pageSpacing: 0,
                  maxZoomLevel: 1,
                  onDocumentLoaded: (details) {
                    setState(() {
                      _totalPages = details.document.pages.count;
                      _isPageLoaded = true; // Set page loaded to true
                    });
                  },
                  onPageChanged: (details) {
                    setState(() {
                      _currentPage = details.newPageNumber;
                      _isPageLoaded = false; // Reset until page fully loads
                    });

                    Future.delayed(const Duration(milliseconds: 200), () {
                      setState(() {
                        _drawingController.setPage(_currentPage);
                        _isPageLoaded =
                            true; // Set after delay to allow rendering
                      });
                    });
                  },
                ),
                Positioned.fill(
                  child: Visibility(
                    child: IgnorePointer(
                      ignoring: _selectedIndex != 0,
                      child: DrawingCanvas(
                        controller: _drawingController,
                        currentPage: _currentPage,
                        callback: () {
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: Text(
                      'Page $_currentPage of $_totalPages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous Button
                    Opacity(
                      opacity: _currentPage > 1 ? 1.0 : 0.5,
                      child: TextButton(
                        onPressed: _currentPage > 1 ? _goToPreviousPage : null,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.arrow_back_ios, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Previous',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Next Button
                    Opacity(
                      opacity: _currentPage < _totalPages ? 1.0 : 0.5,
                      child: TextButton(
                        onPressed:
                            _currentPage < _totalPages ? _goToNextPage : null,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Row(
                          children: const [
                            Text('Next', style: TextStyle(color: Colors.white)),
                            SizedBox(
                              width: 4,
                            ), // Small spacing between text and icon
                            Icon(Icons.arrow_forward_ios, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.undo,
                    color:
                        _drawingController.hasContent()
                            ? Colors.white
                            : Colors.grey[700],
                  ),
                  onPressed:
                      _drawingController.hasContent()
                          ? () {
                            _drawingController.undo();
                            setState(() {});
                          }
                          : null,
                ),
                if (_selectedIndex != -1)
                  IconButton(
                    icon: Icon(
                      Icons.color_lens,
                      color: _drawingController.getCurrentColor,
                    ),
                    onPressed: _selectColor,
                  ),

                if (_selectedIndex == 1)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        _drawingController.addTextBox();
                        setState(() {});
                      },
                      label: Text(
                        "Add Text",
                        style: TextStyle(color: Colors.white),
                      ),
                      icon: Icon(Icons.text_fields),
                    ),
                  ),
                if (_selectedIndex == 0)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).removeCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You can draw on the PDF page'),
                          ),
                        );
                      },
                      label: Text(
                        "Add Drawing",
                        style: TextStyle(color: Colors.white),
                      ),
                      icon: Icon(Icons.draw, color: Colors.white, size: 30),
                    ),
                  ),

                if (_selectedIndex != -1)
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _selectedIndex = -1;
                      });
                    },
                  ),
                IconButton(
                  icon: Icon(
                    Icons.redo,
                    color:
                        _drawingController.hasContent(isRedo: true)
                            ? Colors.white
                            : Colors.grey[700],
                  ),
                  onPressed:
                      _drawingController.hasContent(isRedo: true)
                          ? () {
                            _drawingController.redo();
                            setState(() {});
                          }
                          : null,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.grey[900],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(Icons.edit, "Draw", 0),
            _buildBottomNavItem(Icons.text_fields, "Text", 1),
            _buildBottomNavItem(Icons.highlight, "Highlight", 2),
            _buildBottomNavItem(Icons.format_underlined, "Underline", 3),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIndex = -1;
          } else {
            _selectedIndex = index;
          }
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey,
            size: isSelected ? 32 : 24,
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: isSelected ? 14 : 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class DrawingCanvas extends StatefulWidget {
  final DrawingController controller;
  final int currentPage;
  final VoidCallback callback;
  const DrawingCanvas({
    required this.controller,
    required this.currentPage,
    required this.callback,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  @override
  void initState() {
    super.initState();
    widget.controller.setPage(widget.currentPage);
    widget.controller.addListener(() {
      setState(() {}); // Triggers rebuild when DrawingController updates
    });
  }

  @override
  void didUpdateWidget(DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      widget.controller.setPage(widget.currentPage);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(() {
      setState(() {});
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart:
          (details) => widget.controller.startDraw(details.localPosition),
      onPanUpdate:
          (details) => widget.controller.drawing(details.localPosition),
      onPanEnd: (details) => widget.callback(),

      onTapUp: (details) {
        widget.controller.selectTextBox(details.localPosition);
      },
      child: Stack(
        children: [
          ClipRect(
            child: RepaintBoundary(
              key: widget.controller.painterKey,
              child: CustomPaint(
                painter: DrawingPainter(controller: widget.controller),
                size: Size.infinite,
              ),
            ),
          ),
          ...widget.controller.getTextBoxes().map((textBox) {
            return Positioned(
              left: textBox.position.dx,
              top: textBox.position.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    textBox.position += details.delta;
                  });
                },
                onDoubleTap: () async {
                  String? newText = await _showTextEditDialog(
                    context,
                    textBox.text,
                  );
                  if (newText != null) {
                    setState(() {
                      textBox.text = newText;
                    });
                  }
                },
                child: Container(
                  width: textBox.width,
                  height: textBox.height,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Center(
                    child: Text(textBox.text, textAlign: TextAlign.center),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<String?> _showTextEditDialog(
    BuildContext context,
    String initialText,
  ) async {
    TextEditingController controller = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Text"),
          content: TextField(controller: controller),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }
}

class DrawingController extends ChangeNotifier {
  final Map<int, List<TextBox>> _textBoxes = {};
  final Map<int, List<PaintContent>> _history = {};
  final Map<int, List<PaintContent>> _undoStack = {};
  final GlobalKey painterKey = GlobalKey();
  int _currentPage = 0;
  List<PaintContent> get getHistory => _history[_currentPage] ?? [];
  List<TextBox> getTextBoxes() => _textBoxes[_currentPage] ?? [];
  Map<int, List<TextBox>> getAllTextBoxes() => _textBoxes;
  // ✅ New: Default drawing color
  Color _currentColor = Colors.red;
  Color get getCurrentColor => _currentColor;
  void setColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  void setPage(int page) {
    _currentPage = page;
    _textBoxes.putIfAbsent(page, () => []);
    _history.putIfAbsent(page, () => []);
    _undoStack.putIfAbsent(page, () => []);
    notifyListeners();
  }

  void selectTextBox(Offset tapPosition) {
    for (var textBox in _textBoxes[_currentPage] ?? []) {
      Rect textBoxRect = Rect.fromLTWH(
        textBox.position.dx,
        textBox.position.dy,
        textBox.width,
        textBox.height,
      );

      if (textBoxRect.contains(tapPosition)) {
        // Do something when a text box is selected, like highlighting or allowing drag
        notifyListeners();
        return;
      }
    }
  }

  void startDraw(Offset startPoint) {
    _history.putIfAbsent(_currentPage, () => []);
    _undoStack.putIfAbsent(_currentPage, () => []);

    // ✅ Pass selected color to the SimpleLine
    _history[_currentPage]!.add(SimpleLine(startPoint, _currentColor));
    notifyListeners();
  }

  void drawing(Offset nowPaint) {
    if (_history[_currentPage]?.isNotEmpty == true) {
      _history[_currentPage]!.last.update(nowPaint);
      notifyListeners();
    }
  }

  void endDraw() {
    notifyListeners();
  }

  void addTextBox() {
    _textBoxes[_currentPage] ??= [];
    _textBoxes[_currentPage]!.add(TextBox("New Text", Offset(100, 100)));
    notifyListeners();
  }

  void undo() {
    if (_history[_currentPage]?.isNotEmpty == true) {
      _undoStack[_currentPage]!.add(_history[_currentPage]!.removeLast());
      notifyListeners();
    }
  }

  void redo() {
    if (_undoStack[_currentPage]?.isNotEmpty == true) {
      _history[_currentPage]!.add(_undoStack[_currentPage]!.removeLast());
      notifyListeners();
    }
  }

  bool hasContent({bool isRedo = false}) {
    if (isRedo) {
      return _undoStack[_currentPage]?.isNotEmpty == true;
    }
    return _history[_currentPage]?.isNotEmpty == true ||
        _textBoxes[_currentPage]?.isNotEmpty == true;
  }

  Future<ByteData?> getImageData(int page) async {
    try {
      final RenderRepaintBoundary boundary =
          painterKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;

      // Increase pixel ratio to 3.0 or higher for higher resolution
      final ui.Image originalImage = await boundary.toImage(pixelRatio: 3.0);

      // Create a recorder to capture the flipped image
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      final double height = originalImage.height.toDouble();

      // Flip vertically: Translate and scale
      canvas.translate(0, height);
      canvas.scale(1, -1); // Only invert Y-axis

      // Draw the original image onto the flipped canvas
      final Paint paint = Paint();
      canvas.drawImage(originalImage, Offset.zero, paint);

      // End recording and create a new image
      final ui.Image flippedImage = await recorder.endRecording().toImage(
        originalImage.width,
        originalImage.height,
      );

      // Convert flipped image to byte data (PNG format)
      return await flippedImage.toByteData(format: ui.ImageByteFormat.png);
    } catch (e) {
      debugPrint('Error capturing or flipping image: $e');
      return null;
    }
  }

  Map<int, List<PaintContent>> getAllDrawings() {
    return _history;
  }
}

abstract class PaintContent {
  void paintOnCanvas(Canvas canvas);
  void update(Offset newPoint);
}

class SimpleLine extends PaintContent {
  List<Offset> points = [];
  Color color; // New color for line

  SimpleLine(Offset startPoint, this.color) {
    points.add(startPoint);
  }

  @override
  void update(Offset newPoint) {
    points.add(newPoint);
  }

  @override
  void paintOnCanvas(Canvas canvas) {
    final paint =
        Paint()
          ..color =
              color // ✅ Use the stored color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }
}

class TextBox {
  String text;
  Offset position;
  double width = 100;
  double height = 50;
  double fontSize = 16;

  TextBox(this.text, this.position);
}

class DrawingPainter extends CustomPainter {
  final DrawingController controller;
  DrawingPainter({required this.controller}) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    for (var content in controller.getHistory) {
      content.paintOnCanvas(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
