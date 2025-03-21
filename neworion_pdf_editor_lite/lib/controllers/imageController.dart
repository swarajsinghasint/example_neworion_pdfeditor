import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class ImageController extends ChangeNotifier {
  final Map<int, List<ImageBox>> _imageBoxes = {};
  final Map<int, List<ImageAction>> _history = {};
  final Map<int, List<ImageAction>> _undoStack = {};
  int _currentPage = 0;
  // Get images for the current page
  List<ImageBox> getImageBoxes() => _imageBoxes[_currentPage] ?? [];
  Map<int, List<ImageBox>> getAllImageBoxes() => _imageBoxes;

  // Set current page
  void setPage(int page) {
    _currentPage = page;
    _imageBoxes.putIfAbsent(page, () => []);
    _history.putIfAbsent(page, () => []);
    _undoStack.putIfAbsent(page, () => []);
    notifyListeners();
  }

  // Add image to the current page
  void addImage(ui.Image image) {
    ImageBox newImageBox = ImageBox(
      image: image,
      position: Offset(100, 100),
      width: 150,
      height: 150,
    );
    _imageBoxes[_currentPage]!.add(newImageBox);
    _history[_currentPage]!.add(ImageAction(newImageBox, isAdd: true));
    notifyListeners();
  }

  // Remove image
  void removeImage(ImageBox imageBox) {
    _imageBoxes[_currentPage]?.remove(imageBox);
    _history[_currentPage]!.add(ImageAction(imageBox, isAdd: false));
    notifyListeners();
  }

  // Undo last action
  void undo() {
    if (_history[_currentPage]?.isNotEmpty == true) {
      var lastAction = _history[_currentPage]!.removeLast();
      _undoStack[_currentPage]!.add(lastAction);

      if (lastAction.isAdd) {
        _imageBoxes[_currentPage]?.remove(lastAction.imageBox);
      } else {
        _imageBoxes[_currentPage]?.add(lastAction.imageBox);
      }
      notifyListeners();
    }
  }

  // Redo last undone action
  void redo() {
    if (_undoStack[_currentPage]?.isNotEmpty == true) {
      var lastAction = _undoStack[_currentPage]!.removeLast();
      _history[_currentPage]!.add(lastAction);

      if (lastAction.isAdd) {
        _imageBoxes[_currentPage]?.add(lastAction.imageBox);
      } else {
        _imageBoxes[_currentPage]?.remove(lastAction.imageBox);
      }
      notifyListeners();
    }
  }

  // Check if content is available
  bool hasContent({bool isRedo = false}) {
    return isRedo
        ? _undoStack[_currentPage]?.isNotEmpty == true
        : _history[_currentPage]?.isNotEmpty == true;
  }

  // Clear all image actions
  void clear() {
    _imageBoxes[_currentPage]?.clear();
    _history[_currentPage]?.clear();
    _undoStack[_currentPage]?.clear();
    notifyListeners();
  }

  bool hasClearContent() {
    return _history[_currentPage]?.isNotEmpty == true ||
        _imageBoxes[_currentPage]?.isNotEmpty == true ||
        _undoStack[_currentPage]?.isNotEmpty == true;
  }
}

// ✅ Image Box Class
class ImageBox {
  Offset position;
  double width;
  double height;
  ui.Image image;
  double rotation; // ✅ New rotation field

  ImageBox({
    required this.position,
    required this.width,
    required this.height,
    required this.image,
    this.rotation = 0.0, // ✅ Default rotation
  });
}

// ✅ Image Action for Undo/Redo
class ImageAction {
  final ImageBox imageBox;
  final bool isAdd;

  ImageAction(this.imageBox, {required this.isAdd});
}

class ImagePainter extends CustomPainter {
  final ImageBox imageBox;
  ImagePainter(this.imageBox);

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, imageBox.width, imageBox.height),
      image: imageBox.image,
      fit: BoxFit.contain,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
