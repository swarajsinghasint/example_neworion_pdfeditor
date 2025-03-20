  // Container(
  //           color: Colors.black,
  //           padding: const EdgeInsets.symmetric(horizontal: 12.0),
  //           child: Stack(
  //             children: [
  //               Positioned.fill(
  //                 child: Center(
  //                   child: Text(
  //                     'Page $_currentPage of $_totalPages',
  //                     style: const TextStyle(
  //                       color: Colors.white,
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   // Previous Button
  //                   Opacity(
  //                     opacity: _currentPage > 1 ? 1.0 : 0.5,
  //                     child: TextButton(
  //                       onPressed: _currentPage > 1 ? _goToPreviousPage : null,
  //                       style: TextButton.styleFrom(
  //                         foregroundColor: Colors.white,
  //                       ),
  //                       child: Row(
  //                         children: const [
  //                           Icon(Icons.arrow_back_ios, color: Colors.white),
  //                           SizedBox(width: 4),
  //                           Text(
  //                             'Previous',
  //                             style: TextStyle(color: Colors.white),
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                   ),

  //                   // Next Button
  //                   Opacity(
  //                     opacity: _currentPage < _totalPages ? 1.0 : 0.5,
  //                     child: TextButton(
  //                       onPressed:
  //                           _currentPage < _totalPages ? _goToNextPage : null,
  //                       style: TextButton.styleFrom(
  //                         foregroundColor: Colors.white,
  //                       ),
  //                       child: Row(
  //                         children: const [
  //                           Text('Next', style: TextStyle(color: Colors.white)),
  //                           SizedBox(
  //                             width: 4,
  //                           ), // Small spacing between text and icon
  //                           Icon(Icons.arrow_forward_ios, color: Colors.white),
  //                         ],
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),

  //         Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //             children: [
  //               IconButton(
  //                 icon: Icon(
  //                   Icons.undo,
  //                   color:
  //                       _drawingController.hasContent()
  //                           ? Colors.white
  //                           : Colors.grey[700],
  //                 ),
  //                 onPressed:
  //                     _drawingController.hasContent()
  //                         ? () {
  //                           _drawingController.undo();
  //                           setState(() {});
  //                         }
  //                         : null,
  //               ),
  //               if (_selectedIndex != -1)
  //                 IconButton(
  //                   icon: Icon(
  //                     Icons.color_lens,
  //                     color: _drawingController.getCurrentColor,
  //                   ),
  //                   onPressed: _selectColor,
  //                 ),

  //               if (_selectedIndex == 1)
  //                 Container(
  //                   decoration: BoxDecoration(
  //                     color: Colors.blue,
  //                     borderRadius: BorderRadius.circular(20),
  //                   ),
  //                   child: TextButton.icon(
  //                     onPressed: () {
  //                       _drawingController.addTextBox();
  //                       setState(() {});
  //                     },
  //                     label: Text(
  //                       "Add Text",
  //                       style: TextStyle(color: Colors.white),
  //                     ),
  //                     icon: Icon(Icons.text_fields),
  //                   ),
  //                 ),
  //               if (_selectedIndex == 0)
  //                 Container(
  //                   decoration: BoxDecoration(
  //                     color: Colors.blue,
  //                     borderRadius: BorderRadius.circular(20),
  //                   ),
  //                   child: TextButton.icon(
  //                     onPressed: () {
  //                       ScaffoldMessenger.of(context).removeCurrentSnackBar();
  //                       ScaffoldMessenger.of(context).showSnackBar(
  //                         const SnackBar(
  //                           content: Text('You can draw on the PDF page'),
  //                         ),
  //                       );
  //                     },
  //                     label: Text(
  //                       "Add Drawing",
  //                       style: TextStyle(color: Colors.white),
  //                     ),
  //                     icon: Icon(Icons.draw, color: Colors.white, size: 30),
  //                   ),
  //                 ),

  //               if (_selectedIndex != -1)
  //                 IconButton(
  //                   icon: const Icon(Icons.check, color: Colors.white),
  //                   onPressed: () {
  //                     setState(() {
  //                       _selectedIndex = -1;
  //                     });
  //                   },
  //                 ),
  //               IconButton(
  //                 icon: Icon(
  //                   Icons.redo,
  //                   color:
  //                       _drawingController.hasContent(isRedo: true)
  //                           ? Colors.white
  //                           : Colors.grey[700],
  //                 ),
  //                 onPressed:
  //                     _drawingController.hasContent(isRedo: true)
  //                         ? () {
  //                           _drawingController.redo();
  //                           setState(() {});
  //                         }
  //                         : null,
  //               ),
  //             ],
  //           ),
  //         ),