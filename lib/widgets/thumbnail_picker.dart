import 'dart:io';
import 'package:flutter/material.dart';
import '../models/db/page_model.dart';

class ThumbnailPicker extends StatelessWidget {
  final List<PageModel> pages;
  final int? selectedPageId;
  final Function(int?) onPageSelected;
  final Function(File) onFileSelected;

  const ThumbnailPicker({
    super.key,
    required this.pages,
    this.selectedPageId,
    required this.onPageSelected,
    required this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return const Center(
        child: Text('No pages available'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Thumbnail',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              childAspectRatio: 0.75,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: pages.length,
            itemBuilder: (context, index) {
              final page = pages[index];
              final isSelected = page.pageId == selectedPageId;
              final file = File(page.storagePath);

              return GestureDetector(
                onTap: () {
                  if (page.pageId != null) {
                    onPageSelected(page.pageId);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected 
                          ? Theme.of(context).primaryColor 
                          : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.file(
                          file,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Page ${page.pageNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}








