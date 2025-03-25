import 'package:flutter/foundation.dart';
import 'package:neworion_pdf_editor_lite/controllers/annotationController.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class UnderlineController extends ChangeNotifier {
  final Map<int, List<AnnotationAction>> _underlineHistory = {};
  final Map<int, List<AnnotationAction>> _underlineUndoStack = {};

  int _currentPage = 0;
  Map<int, List<AnnotationAction>> get getUnderlineHistory => _underlineHistory;
  void setPage(int page) {
    _currentPage = page;
    _underlineHistory.putIfAbsent(page, () => []);
    _underlineUndoStack.putIfAbsent(page, () => []);
    notifyListeners();
  }

  void addAnnotation(AnnotationAction annotationAction) {
    _underlineHistory[_currentPage]!.add(annotationAction);
    _underlineUndoStack[_currentPage]!
        .clear(); // Clear redo stack after new action
    notifyListeners();
  }

  // ✅ Undo for Underline
  void undo(PdfViewerController pdfViewerController) {
    if (_underlineHistory[_currentPage]?.isNotEmpty == true) {
      var lastAction = _underlineHistory[_currentPage]!.removeLast();
      _underlineUndoStack[_currentPage]!.add(lastAction);
      pdfViewerController.removeAnnotation(lastAction.annotation);
      notifyListeners();
    }
  }

  // ✅ Redo for Underline
  void redo(PdfViewerController pdfViewerController) {
    if (_underlineUndoStack[_currentPage]?.isNotEmpty == true) {
      var lastAction = _underlineUndoStack[_currentPage]!.removeLast();
      _underlineHistory[_currentPage]!.add(lastAction);
      pdfViewerController.addAnnotation(lastAction.annotation);
      notifyListeners();
    }
  }

  // ✅ Clear Underline
  void clear() {
    _underlineHistory[_currentPage]?.clear();
    _underlineUndoStack[_currentPage]?.clear();
    notifyListeners();
  }

  // ✅ Check if content exists
  bool hasContent({bool isRedo = false}) {
    return isRedo
        ? _underlineUndoStack[_currentPage]?.isNotEmpty == true
        : _underlineHistory[_currentPage]?.isNotEmpty == true;
  }

  bool hasClearContent() {
    return _underlineHistory[_currentPage]?.isNotEmpty == true ||
        _underlineUndoStack[_currentPage]?.isNotEmpty == true;
  }

  clearAllPages(PdfViewerController pdfViewerController) {
    _underlineHistory.clear();
    _underlineUndoStack.clear();
    pdfViewerController.removeAllAnnotations();

    setPage(0);
    notifyListeners();
  }
}
