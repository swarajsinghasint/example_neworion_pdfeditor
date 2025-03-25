import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:neworion_pdf_editor_lite/controllers/annotationController.dart';
import 'package:neworion_pdf_editor_lite/controllers/drawingController.dart';
import 'package:neworion_pdf_editor_lite/controllers/highlightController.dart';
import 'package:neworion_pdf_editor_lite/controllers/imageController.dart';
import 'package:neworion_pdf_editor_lite/controllers/textBoxController.dart';
import 'package:neworion_pdf_editor_lite/controllers/underlineController.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class SavePdfController extends ChangeNotifier {
  bool isSaving = false;

  Future<void> saveDrawing({
    required pdfFile,
    required int totalPages,
    required BuildContext context,
    required DrawingController drawingController,
    required ImageController imageController,
    required TextBoxController textBoxController,
    required HighlightController highlightController,
    required UnderlineController underlineController,
    required Function refresh,
  }) async {
    if (isSaving) {
      return;
    }
    try {
      isSaving = true; // Start loader

      final pdfDoc = PdfDocument(inputBytes: await pdfFile.readAsBytes());

      for (int i = 0; i < totalPages; i++) {
        // Switch page and set drawing for the current page
        drawingController.setPage(i + 1);
        PdfPage page = pdfDoc.pages[i];
        // Delay to allow page change to complete
        await Future.delayed(const Duration(milliseconds: 200));

        // Get drawing data as image and add it to the PDF
        ByteData? imageData = await drawingController.getImageData(i + 1);
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

        for (var imageBox in imageController.getAllImageBoxes()[i + 1] ?? []) {
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
              (-scaledWidth / 2) + 14, // Move to center before drawing
              (-scaledHeight / 2) + 14,
              scaledWidth,
              scaledHeight,
            ),
          );

          // ✅ Restore original graphics state
          page.graphics.restore();
        }

        // ✅ Draw text boxes on the PDF
        for (TextBox textBox
            in textBoxController.getAllTextBoxes()[i + 1] ?? []) {
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
            in highlightController.getHighlightHistory[i + 1] ?? []) {
          if (action.isAdd) {
            for (int j = 0; j < action.pdfAnnotation.length; j++) {
              if (i < pdfDoc.pages.count) {
                pdfDoc.pages[i].annotations.add(action.pdfAnnotation[j]);
              }
            }
          }
        }
        for (AnnotationAction action
            in underlineController.getUnderlineHistory[i + 1] ?? []) {
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
      final String originalName = pdfFile.path.split('/').last.split('.').first;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // Create new file name with timestamp
      final String savedPath = '${output.path}/${originalName}_$timestamp.pdf';
      final file = File(savedPath);

      await file.writeAsBytes(await pdfDoc.save());
      pdfDoc.dispose();

      Navigator.pop(context, file); // Return saved file to previous screen

      // Open the saved PDF
      // OpenFile.open(savedPath);
    } catch (e) {
      debugPrint('Error while saving drawing and text: $e');
    } finally {
      isSaving = false; // Stop loader
    }
  }

  Future<Uint8List> _convertImageToUint8List(ui.Image image) async {
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }
}
