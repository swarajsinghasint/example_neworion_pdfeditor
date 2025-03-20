import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:neworion_pdf_editor_lite/components/colorPicker.dart';
import 'package:neworion_pdf_editor_lite/components/textEditingBox.dart';
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
  final AnnotationController _annotationController = AnnotationController();
  Color _highlightColor = Colors.yellow;
  Color _underlineColor = Colors.green;

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

  void _selectAnnotationColor(bool isHighlight) async {
    Color selectedColor = await showColorPicker(
      context,
      isHighlight ? _highlightColor : _underlineColor,
    );

    if (selectedColor != null) {
      setState(() {
        if (isHighlight) {
          _highlightColor = selectedColor;
        } else {
          _underlineColor = selectedColor;
        }
      });
    }
  }

  void _selectColor() async {
    Color selectedColor = await showColorPicker(
      context,
      _drawingController._currentColor,
    );
    _drawingController.setColor(selectedColor);
    setState(() {});
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

        // Get drawing data as image and add it to the PDF
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

        // ✅ Draw text boxes on the PDF
        for (TextBox textBox
            in _drawingController.getAllTextBoxes()[i + 1] ?? []) {
          PdfPage page = pdfDoc.pages[i];

          final double scaleFactorX =
              page.getClientSize().width / MediaQuery.of(context).size.width;
          final double scaleFactorY =
              page.getClientSize().height /
              (MediaQuery.of(context).size.width *
                  1.414); // Adjust for aspect ratio

          // Properly manage text position with corrected offsets and scaling
          double scaledX = textBox.position.dx * scaleFactorX;
          double scaledY = textBox.position.dy * scaleFactorY;
          double scaledWidth = textBox.width * scaleFactorX;
          double scaledHeight = textBox.height * scaleFactorY;

          // Draw text with corrected bounds and alignment
          page.graphics.drawString(
            textBox.text,
            PdfStandardFont(PdfFontFamily.helvetica, textBox.fontSize),
            brush: PdfSolidBrush(
              PdfColor(
                textBox.color?.red ?? 0,
                textBox.color?.green ?? 0,
                textBox.color?.blue ?? 0,
              ),
            ),
            bounds: Rect.fromLTWH(
              scaledX + 10, // Added padding to avoid edge cutoff
              scaledY + 10,
              scaledWidth,
              scaledHeight,
            ),
            format: PdfStringFormat(
              alignment: PdfTextAlignment.center,
              lineAlignment: PdfVerticalAlignment.middle,
            ),
          );
        }

        // ✅ Add Annotations (Highlight/Underline)
        for (AnnotationAction action
            in _annotationController._annotationHistory[i + 1] ?? []) {
          if (action.isAdd) {
            for (int j = 0; j < action.pdfAnnotation.length; j++) {
              if (i < pdfDoc.pages.count) {
                pdfDoc.pages[i].annotations.add(action.pdfAnnotation[j]);
              }
            }
          }
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
      debugPrint('Error while saving drawing and text: $e');
    }
  }

  Future<void> _annotateText(bool isHighlight) async {
    List<PdfTextLine>? textLines =
        _pdfViewerKey.currentState?.getSelectedTextLines();
    if (textLines != null && textLines.isNotEmpty) {
      List<PdfTextMarkupAnnotation> pdfAnnotations = [];
      PdfColor selectedColor =
          isHighlight
              ? PdfColor(
                _highlightColor.red,
                _highlightColor.green,
                _highlightColor.blue,
              )
              : PdfColor(
                _underlineColor.red,
                _underlineColor.green,
                _underlineColor.blue,
              );

      for (var line in textLines) {
        PdfTextMarkupAnnotation annotation = PdfTextMarkupAnnotation(
          line.bounds,
          line.text,
          selectedColor,
          textMarkupAnnotationType:
              isHighlight
                  ? PdfTextMarkupAnnotationType.highlight
                  : PdfTextMarkupAnnotationType.underline,
        );
        pdfAnnotations.add(annotation);
      }

      Annotation displayAnnotation;
      if (isHighlight) {
        displayAnnotation = HighlightAnnotation(
          textBoundsCollection: textLines,
        );
      } else {
        displayAnnotation = UnderlineAnnotation(
          textBoundsCollection: textLines,
        );
      }

      _pdfViewerController.addAnnotation(displayAnnotation);
      _annotationController.addAnnotation(
        AnnotationAction(
          displayAnnotation,
          isHighlight ? AnnotationType.highlight : AnnotationType.underline,
          pdfAnnotations,
          isAdd: true,
        ),
      );
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
                    _annotationController.setPage(_currentPage);
                  },
                  onPageChanged: (details) {
                    setState(() {
                      _currentPage = details.newPageNumber;
                      _isPageLoaded = false; // Reset until page fully loads
                    });
                    _drawingController.setPage(_currentPage);
                    _annotationController.setPage(_currentPage);
                    Future.delayed(const Duration(milliseconds: 400), () {
                      setState(() {
                        _isPageLoaded =
                            true; // Set after delay to allow rendering
                      });
                    });
                  },
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: _isPageLoaded ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: _selectedIndex != 0 && _selectedIndex != 1,
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: _goToPreviousPage,
              ),
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white),
                onPressed: () {
                  if (_selectedIndex == 2) {
                    _annotationController.undo(_pdfViewerController);
                  } else {
                    _drawingController.undo();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.redo, color: Colors.white),
                onPressed: () {
                  if (_selectedIndex == 2) {
                    _annotationController.redo(_pdfViewerController);
                  } else {
                    _drawingController.redo();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.color_lens, color: Colors.white),
                onPressed: () {
                  _selectedIndex == 2
                      ? _selectAnnotationColor(true)
                      : _selectColor();
                },
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  _drawingController.addTextBox();
                  setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: _goToNextPage,
              ),
            ],
          ),

          IconButton(
            icon: const Icon(Icons.highlight, color: Colors.white),
            onPressed: () => _annotateText(true),
          ),
          IconButton(
            icon: const Icon(Icons.format_underlined, color: Colors.white),
            onPressed: () => _annotateText(false),
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
            _buildBottomNavItem(Icons.highlight, "Annotate", 2),
            _buildBottomNavItem(Icons.image_outlined, "Image", 3),
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
                onTap: () async {
                  Map<String, dynamic>? result = await _showTextEditDialog(
                    context,
                    textBox,
                  );

                  if (result != null) {
                    setState(() {
                      textBox.text = result["text"] as String;
                      textBox.fontSize = result["fontSize"] as double;
                      textBox.color = result["color"] as Color;
                    });
                  }
                },
                child: Stack(
                  children: [
                    Container(
                      width: textBox.width,
                      height: textBox.height,
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Center(
                        child: Text(
                          textBox.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: textBox.fontSize,
                            color: textBox.color ?? Colors.black,
                            fontFamily: 'Helvetica',
                          ),
                        ),
                      ),
                    ),
                    // Cross Icon to Remove Text Box
                    Positioned(
                      right: -0, // Positioned correctly to avoid overlap
                      top: -0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            widget.controller.removeTextBox(textBox);
                          });
                        },
                        child: const CircleAvatar(
                          backgroundColor: Colors.red,
                          radius: 10,
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Resize Icon at Bottom Right
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            textBox.width += details.delta.dx;
                            textBox.height += details.delta.dy;
                          }); // Prevent negative width/height
                          textBox.width = textBox.width.clamp(
                            20,
                            double.infinity,
                          );
                          textBox.height = textBox.height.clamp(
                            20,
                            double.infinity,
                          );
                        },
                        child: const Icon(
                          Icons.open_with,
                          size: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showTextEditDialog(
    BuildContext context,
    TextBox textBox,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return TexteditingboxContent(textBox: textBox);
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

  void addTextBox() {
    _textBoxes[_currentPage] ??= [];
    TextBox newTextBox = TextBox("New Text", Offset(100, 100));
    _textBoxes[_currentPage]!.add(newTextBox);
    _history[_currentPage]!.add(TextBoxAction(newTextBox, isAdd: true));
    notifyListeners();
  }

  void removeTextBox(TextBox textBox) {
    _textBoxes[_currentPage]?.remove(textBox);
    _history[_currentPage]!.add(TextBoxAction(textBox, isAdd: false));
    notifyListeners();
  }

  void selectTextBox(Offset tapPosition) {
    for (TextBox textBox in _textBoxes[_currentPage] ?? []) {
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

  void undo() {
    if (_history[_currentPage]?.isNotEmpty == true) {
      var lastAction = _history[_currentPage]!.removeLast();
      _undoStack[_currentPage]!.add(lastAction);

      if (lastAction is SimpleLine) {
        // Handle drawing undo
        notifyListeners();
      } else if (lastAction is TextBoxAction) {
        // Handle text box undo
        if (lastAction.isAdd) {
          _textBoxes[_currentPage]?.remove(lastAction.textBox);
        } else {
          _textBoxes[_currentPage]?.add(lastAction.textBox);
        }
      }
      notifyListeners();
    }
  }

  void redo() {
    if (_undoStack[_currentPage]?.isNotEmpty == true) {
      var lastAction = _undoStack[_currentPage]!.removeLast();
      _history[_currentPage]!.add(lastAction);

      if (lastAction is SimpleLine) {
        // Redo drawing
        notifyListeners();
      } else if (lastAction is TextBoxAction) {
        // Redo text box
        if (lastAction.isAdd) {
          _textBoxes[_currentPage]?.add(lastAction.textBox);
        } else {
          _textBoxes[_currentPage]?.remove(lastAction.textBox);
        }
      }
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

class AnnotationController extends ChangeNotifier {
  final Map<int, List<AnnotationAction>> _annotationHistory = {};
  final Map<int, List<AnnotationAction>> _annotationUndoStack = {};
  int _currentPage = 0;

  void setPage(int page) {
    _currentPage = page;
    _annotationHistory.putIfAbsent(page, () => []);
    _annotationUndoStack.putIfAbsent(page, () => []);
    notifyListeners();
  }

  void addAnnotation(AnnotationAction annotationAction) {
    _annotationHistory[_currentPage]!.add(annotationAction);
    _annotationUndoStack[_currentPage]!
        .clear(); // Clear redo stack after new action
    notifyListeners();
  }

  void undo(PdfViewerController pdfViewerController) {
    if (_annotationHistory[_currentPage]?.isNotEmpty == true) {
      var lastAction = _annotationHistory[_currentPage]!.removeLast();
      _annotationUndoStack[_currentPage]!.add(lastAction);

      pdfViewerController.removeAnnotation(lastAction.annotation);
      notifyListeners();
    }
  }

  void redo(PdfViewerController pdfViewerController) {
    if (_annotationUndoStack[_currentPage]?.isNotEmpty == true) {
      var lastAction = _annotationUndoStack[_currentPage]!.removeLast();
      _annotationHistory[_currentPage]!.add(lastAction);

      pdfViewerController.addAnnotation(lastAction.annotation);
      notifyListeners();
    }
  }

  void clear() {
    _annotationHistory[_currentPage]?.clear();
    _annotationUndoStack[_currentPage]?.clear();
    notifyListeners();
  }

  bool hasContent({bool isRedo = false}) {
    return isRedo
        ? _annotationUndoStack[_currentPage]?.isNotEmpty == true
        : _annotationHistory[_currentPage]?.isNotEmpty == true;
  }
}

// ✅ Annotation Types
enum AnnotationType { highlight, underline }

// ✅ Annotation Action Class
class AnnotationAction {
  final Annotation annotation;
  final AnnotationType type;
  final bool isAdd;
  final List<PdfTextMarkupAnnotation> pdfAnnotation;

  AnnotationAction(
    this.annotation,
    this.type,
    this.pdfAnnotation, {
    this.isAdd = true,
  });
}

class TextBox {
  String text;
  Offset position;
  double width;
  double height;
  double fontSize;
  Color? color;

  TextBox(
    this.text,
    this.position, {
    this.width = 100,
    this.height = 50,
    this.fontSize = 12,
    this.color,
  });
}

class TextBoxAction extends PaintContent {
  final TextBox textBox;
  final bool isAdd;

  TextBoxAction(this.textBox, {required this.isAdd});

  @override
  void paintOnCanvas(Canvas canvas) {
    // No painting required for undo/redo actions
  }

  @override
  void update(Offset newPoint) {}
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
