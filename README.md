  # QRganize

  QRganize is a Flutter-based desktop application for organizing and
  reading your local comic book collection. It provides a simple and
  intuitive interface to browse your comics, view pages, and even add and
  manage translations for them.

  ## Features

     Comic Organization*: Select and scan your local comic directory to automatically organize your collection.
     Multiple Viewing Modes*: View your comic collection in a grid, list, or other layouts.
     Comic Viewer*: A feature-rich comic viewer with fullscreen mode and easy navigation.
     Translation Support*: Add, edit, and view translations for your comic pages.
      *   Create and resize translation boxes directly on the comic page.
      *   Use the integrated DeepL API to automatically translate text.
     Sorting and Filtering*: Sort your comics and pages by name, date, or number of translations.
     File Explorer Integration*: Quickly open the comic's folder from within the application (Windows only).

  ## Getting Started

  ### Prerequisites

  *   Flutter SDK (https://docs.flutter.dev/get-started/install)
  *   A code editor like Visual Studio Code
  (https://code.visualstudio.com/) or Android Studio
  (https://developer.android.com/studio).

  ### Installation

  1.  Clone the repository:
      `bash
      git clone https://github.com/your-username/qrganize.git
      `
  2.  Navigate to the project directory:
      `bash
      cd qrganize
      `
  3.  Install the dependencies:
      `bash
      flutter pub get

  `
  4.  Run the application:
      `bash
      flutter run

  `

  ## How to Use

  1.  Select Your Comics Directory: On the first launch, you will be
  prompted to select the root directory where your comics are stored. You
  can change this directory later from the settings.
  2.  Browse Your Collection: The application will scan the directory and
  display your comics. You can navigate through subfolders and view your
  comics in different layouts.
  3.  Read Comics: Click on a comic to open the gallery view, then click
  on a page to open the viewer.
  4.  Translations:
      *   In the viewer, switch to "Edit Mode" to create translation
  boxes.
      *   Draw a box over the text you want to translate.
      *   Double-click the box to add or edit the translation.
      *   You can use the DeepL API to automatically translate the text.
  You will need to add your own DeepL API key in the settings.

  ## Technologies Used

  *   Flutter (https://flutter.dev/)
  *   Provider (https://pub.dev/packages/provider) for state management
  *   DeepL API (https://www.deepl.com/pro-api) for translations

  ---