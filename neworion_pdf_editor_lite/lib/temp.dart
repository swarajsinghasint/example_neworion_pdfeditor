//  void _onTextSelectionChanged(PdfTextSelectionChangedDetails details) {
//     if (details.selectedText != null && details.selectedText!.isNotEmpty) {
//       setState(() {
//         _selectedText = details.selectedText!;
//       });
//     }
//   }

//   /// Highlights the selected text and saves the PDF
//   Future<void> _highlightText() async {
//     if (_selectedText.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('No text selected!')));
//       return;
//     }

//     try {
//       // Load the PDF document
//       PdfDocument document = PdfDocument(
//         inputBytes: widget.pdfFile.readAsBytesSync(),
//       );

//       // Extract text from the document
//       // PdfTextExtractor extractor = PdfTextExtractor(document);

//       // final List<PdfTextLine> textLines = extractor.jsify()

//       final List<PdfTextLine>? selectedTextLines =
//           _pdfViewerKey.currentState?.getSelectedTextLines();

//       if (selectedTextLines != null && selectedTextLines.isNotEmpty) {
//         for (var line in selectedTextLines) {
//           print('Selected Text: ${line.text}');

//           print('Word: ${line.text}, Bounds: ${line.bounds}');
//           PdfTextMarkupAnnotation highlight = PdfTextMarkupAnnotation(
//             line.bounds,
//             line.text,
//             PdfColor(255, 255, 0),
//             textMarkupAnnotationType: PdfTextMarkupAnnotationType.highlight,
//           );
//           document.pages[line.pageNumber - 1].annotations.add(highlight);
//         }
//       } else {
//         print("No text selected");
//       }

//       // for (int i = 0; i < document.pages.count; i++) {
//       // List<TextLine> textLines = extractor.extractTextLines(
//       //   startPageIndex: i,
//       //   endPageIndex: i,
//       // );

//       // for (var textLine in textLines) {

//       // if (textLine.text.contains(_selectedText)) {
//       // PdfTextMarkupAnnotation highlight = PdfTextMarkupAnnotation(
//       //   textLine.bounds,
//       //   textLine.text,
//       //   PdfColor(255, 255, 0),
//       //   textMarkupAnnotationType: PdfTextMarkupAnnotationType.highlight,
//       // ); // Yellow highlight

//       //   document.pages[i].annotations.add(highlight);
//       // }
//       // }
//       // }

//       // Save the updated PDF
//       List<int> updatedBytes = await document.save();
//       document.dispose();

//       // Save file to storage
//       final directory = await getApplicationDocumentsDirectory();
//       File updatedPdf = File('${directory.path}/highlighted.pdf');
//       await updatedPdf.writeAsBytes(updatedBytes);

//       // Show success message
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Highlighted text saved successfully!')),
//       );
//       OpenFile.open(updatedPdf.path);
//       // Navigator.pop(context, updatedPdf);
//       // Navigator.pop(context, updatedPdf);
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error highlighting text: $e')));
//     }
//   }



//   class OPMyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('PDF Highlighter')),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () async {
//             await createHighlightedPdf();
//           },
//           child: Text('Create PDF'),
//         ),
//       ),
//     );
//   }
// }

// Future<void> createHighlightedPdf() async {
//   // Create a new PDF document
//   PdfDocument document = PdfDocument();

//   // Add a page to the document
//   PdfPage page = document.pages.add();

//   // Create a new text element with highlight
//   PdfTextMarkupAnnotation highlightAnnotation = PdfTextMarkupAnnotation(
//     Rect.fromLTWH(10, 50, 200, 20),
//     "This is a highlighted text example in Flutter.",
//     PdfColor(255, 255, 150, 150),
//     textMarkupAnnotationType: PdfTextMarkupAnnotationType.highlight,
//   );
//   highlightAnnotation.color = PdfColor(255, 255, 150, 150); // Light yellow
//   page.annotations.add(highlightAnnotation);

//   // Draw the text over the highlighted area
//   PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
//   page.graphics.drawString(
//     "This is a highlighted text example in Flutter.",
//     font,
//     brush: PdfBrushes.black,
//     bounds: Rect.fromLTWH(10, 50, 200, 20),
//     format: PdfStringFormat(alignment: PdfTextAlignment.left),
//   );

//   // Save and close the document
//   List<int> bytes = await document.save();
//   document.dispose();

//   // Get external storage directory
//   Directory directory = await getApplicationDocumentsDirectory();
//   String path = '${directory.path}/HighlightedText.pdf';

//   // Write the file
//   File file = File(path);
//   await file.writeAsBytes(bytes, flush: true);
//   print('PDF saved at: $path');
//   OpenFile.open(file.path);
// }
