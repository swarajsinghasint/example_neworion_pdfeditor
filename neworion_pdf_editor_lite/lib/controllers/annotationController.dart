import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class AnnotationController extends ChangeNotifier {
  final Map<int, List<AnnotationAction>> _annotationHistory = {};
  final Map<int, List<AnnotationAction>> _annotationUndoStack = {};
  int _currentPage = 0;
  Map<int, List<AnnotationAction>> get getAnnotationHistory =>
      _annotationHistory;

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

  bool hasClearContent() {
    return _annotationHistory[_currentPage]?.isNotEmpty == true ||
        _annotationUndoStack[_currentPage]?.isNotEmpty == true;
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
