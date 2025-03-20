import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:neworion_pdf_editor_lite/components/colorPicker.dart';
import 'package:neworion_pdf_editor_lite/components/textEditingBox.dart';
import 'package:neworion_pdf_editor_lite/controllers/annotationController.dart';
import 'package:neworion_pdf_editor_lite/controllers/drawingController.dart';
import 'package:neworion_pdf_editor_lite/controllers/imageController.dart';
import 'package:neworion_pdf_editor_lite/controllers/textBoxController.dart';
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
  final TextBoxController _textBoxController = TextBoxController();
  final ImageController _imageController = ImageController();
  Color _highlightColor = Colors.yellow;
  Color _underlineColor = Colors.green;
  DrawingMode selectedMode = DrawingMode.none;

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

  selectColor() async {
    Color selectedColor = await showColorPicker(
      context,
      _drawingController.getCurrentColor,
    );
    _drawingController.setColor(selectedColor);
    setState(() {});
  }

  Future<Uint8List> _convertImageToUint8List(ui.Image image) async {
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  Future<void> _saveDrawing() async {
    try {
      final pdfDoc = PdfDocument(
        inputBytes: await widget.pdfFile.readAsBytes(),
      );

      for (int i = 0; i < _totalPages; i++) {
        // Switch page and set drawing for the current page
        _drawingController.setPage(i + 1);
        PdfPage page = pdfDoc.pages[i];
        // Delay to allow page change to complete
        await Future.delayed(const Duration(milliseconds: 200));

        // Get drawing data as image and add it to the PDF
        ByteData? imageData = await _drawingController.getImageData(i + 1);
        if (imageData != null) {
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

        // ✅ Add images to PDF

        for (var imageBox in _imageController.getAllImageBoxes()[i + 1] ?? []) {
          final imgData = await _convertImageToUint8List(imageBox.image);
          final PdfImage pdfImage = PdfBitmap(imgData);

          final double scaleFactorX =
              page.getClientSize().width / MediaQuery.of(context).size.width;
          final double scaleFactorY =
              page.getClientSize().height /
              (MediaQuery.of(context).size.width *
                  1.414); // Aspect ratio correction

          // Corrected position and dimensions with scaling
          double scaledX = imageBox.position.dx * scaleFactorX;
          double scaledY = imageBox.position.dy * scaleFactorY;
          double scaledWidth = imageBox.width * scaleFactorX;
          double scaledHeight = imageBox.height * scaleFactorY;

          // ✅ Save the current graphics state
          page.graphics.save();

          // ✅ Apply translation and rotation correctly
          page.graphics.translateTransform(
            scaledX + scaledWidth / 2,
            scaledY + scaledHeight / 2,
          );

          // ✅ Apply rotation (in degrees, converted to radians)
          page.graphics.rotateTransform(imageBox.rotation * (180 / pi));

          // ✅ Draw the rotated image with corrected bounds
          page.graphics.drawImage(
            pdfImage,
            Rect.fromLTWH(
              -scaledWidth / 2, // Move to center before drawing
              -scaledHeight / 2,
              scaledWidth,
              scaledHeight,
            ),
          );

          // ✅ Restore original graphics state
          page.graphics.restore();
        }

        // ✅ Draw text boxes on the PDF
        for (TextBox textBox
            in _textBoxController.getAllTextBoxes()[i + 1] ?? []) {
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
            in _annotationController.getAnnotationHistory[i + 1] ?? []) {
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

  Future<void> _addImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      _imageController.addImage(image);
      setState(() {});
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
                          ignoring:
                              _selectedIndex != 0 &&
                              _selectedIndex != 1 &&
                              _selectedIndex != 4,
                          child: DrawingCanvas(
                            drawingController: _drawingController,
                            textBoxController: _textBoxController,
                            imageController: _imageController,
                            currentPage: _currentPage,
                            selectedMode: selectedMode,
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
                            onPressed:
                                _currentPage > 1 ? _goToPreviousPage : null,
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
                                _currentPage < _totalPages
                                    ? _goToNextPage
                                    : null,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: Row(
                              children: const [
                                Text(
                                  'Next',
                                  style: TextStyle(color: Colors.white),
                                ),
                                SizedBox(
                                  width: 4,
                                ), // Small spacing between text and icon
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_selectedIndex == 0) drawOption(),
          if (_selectedIndex == 1) textOption(),
          if (_selectedIndex == 2) highlightOption(),
          if (_selectedIndex == 3) underlineOption(),
          if (_selectedIndex == 4) imageOption(),
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
            _buildBottomNavItem(Icons.format_underline, "Underline", 3),
            _buildBottomNavItem(Icons.image_outlined, "Image", 4),
          ],
        ),
      ),
    );
  }

  Widget buildOptionRow({
    required dynamic controller,
    required VoidCallback onAdd,
    required IconData addIcon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(5.0),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildUndoRedoButton(
            icon: Icons.undo,
            enabled: controller.hasContent(),
            onPressed:
                controller.hasContent()
                    ? () {
                      controller.undo();
                      setState(() {});
                    }
                    : null,
          ),
          _buildUndoRedoButton(
            icon: Icons.redo,
            enabled: controller.hasContent(isRedo: true),
            onPressed:
                controller.hasContent(isRedo: true)
                    ? () {
                      controller.redo();
                      setState(() {});
                    }
                    : null,
          ),
          _buildActionButton(onPressed: onAdd, icon: addIcon, label: label),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.white),
            onPressed: selectColor,
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white, size: 30),
            onPressed: () {
              setState(() {
                _selectedIndex = -1;
              });
            },
          ),
        ],
      ),
    );
  }

  // ✅ Reusable Undo/Redo Button
  Widget _buildUndoRedoButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: enabled ? Colors.white : Colors.grey[700]),
      onPressed: enabled ? onPressed : null,
    );
  }

  // ✅ Reusable Action Button (Add Drawing, Text, Highlight, etc.)
  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        icon: Icon(icon, color: Colors.white, size: 25),
      ),
    );
  }

  // ✅ Draw Option
  Widget drawOption() => buildOptionRow(
    controller: _drawingController,
    onAdd: () async {
      await selectColor();
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can draw on the PDF page')),
      );
    },
    addIcon: Icons.draw,
    label: "Add Drawing",
  );

  // ✅ Text Option
  Widget textOption() => buildOptionRow(
    controller: _textBoxController,
    onAdd: () => _textBoxController.addTextBox(),
    addIcon: Icons.text_fields,
    label: "Add Text",
  );

  // ✅ Highlight Option
  Widget highlightOption() => buildOptionRow(
    controller: _annotationController,
    onAdd: () => _annotateText(true),
    addIcon: Icons.highlight,
    label: "Highlight",
  );

  // ✅ Underline Option
  Widget underlineOption() => buildOptionRow(
    controller: _annotationController,
    onAdd: () => _annotateText(false),
    addIcon: Icons.format_underline,
    label: "Underline",
  );

  // ✅ Image Option
  Widget imageOption() => buildOptionRow(
    controller: _imageController,
    onAdd: () async {
      await _addImage();
    },
    addIcon: Icons.image,
    label: "Add Image",
  );

  void _changeMode(DrawingMode mode) {
    setState(() {
      selectedMode = mode;
    });
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
          switch (index) {
            case 0:
              _changeMode(DrawingMode.draw);
              break;
            case 1:
              _changeMode(DrawingMode.text);
              break;
            case 2:
              _changeMode(DrawingMode.highlight);
              break;
            case 3:
              _changeMode(DrawingMode.underline);
              break;
            case 4:
              _changeMode(DrawingMode.image);
              break;
            default:
              _changeMode(DrawingMode.none);
              break;
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

enum DrawingMode { none, draw, text, image, highlight, underline }

class DrawingCanvas extends StatefulWidget {
  final DrawingController drawingController;
  final TextBoxController textBoxController;
  final ImageController imageController;
  final int currentPage;
  final DrawingMode selectedMode;
  final VoidCallback callback;

  const DrawingCanvas({
    required this.drawingController,
    required this.textBoxController,
    required this.imageController,
    required this.currentPage,
    required this.selectedMode,
    required this.callback,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  @override
  void initState() {
    super.initState();
    widget.drawingController.setPage(widget.currentPage);
    widget.textBoxController.setPage(widget.currentPage);
    widget.imageController.setPage(widget.currentPage);
    widget.drawingController.addListener(() {
      setState(() {});
    });
    widget.textBoxController.addListener(() {
      setState(() {});
    });
    widget.imageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      widget.drawingController.setPage(widget.currentPage);
      widget.textBoxController.setPage(widget.currentPage);
      widget.imageController.setPage(widget.currentPage);
    }
  }

  @override
  void dispose() {
    widget.drawingController.removeListener(() {
      setState(() {});
    });
    widget.textBoxController.removeListener(() {
      setState(() {});
    });
    widget.imageController.removeListener(() {
      setState(() {});
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        if (widget.selectedMode == DrawingMode.draw) {
          widget.drawingController.startDraw(details.localPosition);
        }
      },
      onPanUpdate: (details) {
        if (widget.selectedMode == DrawingMode.draw) {
          widget.drawingController.drawing(details.localPosition);
        }
      },
      onPanEnd: (details) {
        if (widget.selectedMode == DrawingMode.draw) {
          widget.callback();
        }
      },
      onTapUp: (details) {
        if (widget.selectedMode == DrawingMode.text) {
          widget.textBoxController.selectTextBox(details.localPosition);
        }
      },
      child: Stack(
        children: [
          ...widget.imageController.getImageBoxes().map(_buildImageWidget),
          IgnorePointer(
            ignoring: widget.selectedMode != DrawingMode.draw,
            child: ClipRect(
              child: RepaintBoundary(
                key: widget.drawingController.painterKey,
                child: CustomPaint(
                  painter: DrawingPainter(controller: widget.drawingController),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          ...widget.textBoxController.getTextBoxes().map((textBox) {
            return Positioned(
              left: textBox.position.dx,
              top: textBox.position.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (widget.selectedMode == DrawingMode.text) {
                    setState(() {
                      textBox.position += details.delta;
                    });
                  }
                },
                onTap: () async {
                  if (widget.selectedMode != DrawingMode.text) {
                    return;
                  }
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
                            widget.textBoxController.removeTextBox(textBox);
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

  Positioned _buildImageWidget(ImageBox imageBox) {
    return Positioned(
      left: imageBox.position.dx,
      top: imageBox.position.dy,
      child: GestureDetector(
        onScaleUpdate: (details) {
          if (widget.selectedMode == DrawingMode.image) {
            setState(() {
              // ✅ Update position
              imageBox.position += details.focalPointDelta;

              // ✅ Update scale (pinch zoom)
              if (details.scale != 1.0) {
                imageBox.width *= details.scale;
                imageBox.height *= details.scale;
              }

              // ✅ Update rotation
              imageBox.rotation += details.rotation;
            });
          }
        },
        child: Transform(
          transform:
              Matrix4.identity()
                ..translate(imageBox.width / 2, imageBox.height / 2)
                ..rotateZ(imageBox.rotation)
                ..translate(-imageBox.width / 2, -imageBox.height / 2),
          alignment: Alignment.center,
          child: SizedBox(
            width: imageBox.width,
            height: imageBox.height,
            child: CustomPaint(painter: ImagePainter(imageBox)),
          ),
        ),
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
