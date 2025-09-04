import 'dart:io';
import 'package:image/image.dart';

/// This script generates placeholder images for the comic reader application.
/// It creates two comic folders: 'cat_programmer' and 'space_adventure',
/// and places two placeholder images in each folder.
void main() async {
  final String projectRoot = Directory.current.path;
  final Directory comicsDir = Directory('$projectRoot/comics');

  // Ensure the main comics directory exists
  if (!await comicsDir.exists()) {
    await comicsDir.create(recursive: true);
    print('Created directory: ${comicsDir.path}');
  }

  final Map<String, List<String>> comicFolders = {
    'cat_programmer': ['01.png', '02.png'],
    'space_adventure': ['01.png', '02.png'],
  };

  for (final entry in comicFolders.entries) {
    final String folderName = entry.key;
    final List<String> imageNames = entry.value;
    final Directory comicFolderDir = Directory('${comicsDir.path}/$folderName');

    // Ensure each comic folder exists
    if (!await comicFolderDir.exists()) {
      await comicFolderDir.create(recursive: true);
      print('Created directory: ${comicFolderDir.path}');
    }

    for (final imageName in imageNames) {
      createImage(comicFolderDir, imageName);
      print('Created image: ${comicFolderDir.path}/$imageName');
    }
  }

  print('Placeholder image generation complete.');
}

/// Creates a simple placeholder image with text and saves it to the specified directory.
void createImage(Directory dir, String name) {
  final image = Image(width: 350, height: 150);
  // Fill the image with a light gray color
  fill(image, color: ColorRgb8(192, 192, 192));

  // Draw text on the image
  // Ensure the font is available. If not, you might need to load it.
  // For simplicity, using a default font here. In a real app, load a font.
  // Example: BitmapFont font = BitmapFont.fromZip(File('path/to/font.zip').readAsBytesSync());
  // drawString(image, font, x, y, text);
  drawString(image, name, font: arial24, x: 10, y: 10);

  // Save the image to a file
  File('${dir.path}/$name').writeAsBytesSync(encodePng(image));
}