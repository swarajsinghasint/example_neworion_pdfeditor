import 'package:flutter/foundation.dart';
import 'package:neworion_pdf_editor_lite/controllers/annotationController.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class HighlightController extends ChangeNotifier {
  final Map<int, List<AnnotationAction>> _highlightHistory = {};
  final Map<int, List<AnnotationAction>> _highlightUndoStack = {};

  int _currentPage = 0;
  Map<int, List<AnnotationAction>> get getHighlightHistory => _highlightHistory;

  void setPage(int page) {
    _currentPage = page;
    _highlightHistory.putIfAbsent(page, () => []);
    _highlightUndoStack.putIfAbsent(page, () => []);
    notifyListeners();
  }

  void addAnnotation(AnnotationAction annotationAction) {
    _highlightHistory[_currentPage]!.add(annotationAction);
    _highlightUndoStack[_currentPage]!
        .clear(); // Clear redo stack after new action
    notifyListeners();
  }

  // ✅ Undo for Highlight
  void undo(PdfViewerController pdfViewerController) {
    if (_highlightHistory[_currentPage]?.isNotEmpty == true) {
      var lastAction = _highlightHistory[_currentPage]!.removeLast();
      _highlightUndoStack[_currentPage]!.add(lastAction);
      pdfViewerController.removeAnnotation(lastAction.annotation);
      notifyListeners();
    }
  }

  // ✅ Redo for Highlight
  void redo(PdfViewerController pdfViewerController) {
    if (_highlightUndoStack[_currentPage]?.isNotEmpty == true) {
      var lastAction = _highlightUndoStack[_currentPage]!.removeLast();
      _highlightHistory[_currentPage]!.add(lastAction);
      pdfViewerController.addAnnotation(lastAction.annotation);
      notifyListeners();
    }
  }

  // ✅ Clear Highlight
  void clear(PdfViewerController pdfViewerController) {
    _highlightHistory[_currentPage]?.forEach((action) {
      pdfViewerController.removeAnnotation(action.annotation);
    });
    _highlightHistory[_currentPage]?.clear();
    _highlightUndoStack[_currentPage]?.clear();

    notifyListeners();
  }

  hide(PdfViewerController pdfViewerController) {
    _highlightHistory[_currentPage]?.forEach((action) {
      pdfViewerController.removeAnnotation(action.annotation);
    });
  }

  unhide(PdfViewerController pdfViewerController) {
    _highlightHistory[_currentPage]?.forEach((action) {
      pdfViewerController.addAnnotation(action.annotation);
    });
  }
  

  // ✅ Check if content exists
  bool hasContent({bool isRedo = false}) {
    return isRedo
        ? _highlightUndoStack[_currentPage]?.isNotEmpty == true
        : _highlightHistory[_currentPage]?.isNotEmpty == true;
  }

  bool hasClearContent() {
    return _highlightHistory[_currentPage]?.isNotEmpty == true ||
        _highlightUndoStack[_currentPage]?.isNotEmpty == true;
  }

  clearAllPages(PdfViewerController pdfViewerController) {
    _highlightHistory.clear();
    _highlightUndoStack.clear();
    pdfViewerController.removeAllAnnotations();
    setPage(0);
    notifyListeners();
  }
}
