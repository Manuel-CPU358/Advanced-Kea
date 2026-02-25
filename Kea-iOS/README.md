# Kea iOS (Swift / Xcode rewrite)

This folder contains a SwiftUI rewrite of the original Kea downloader for iPhone.

## Included features parity

- Add multiple Webtoon list URLs into a queue.
- Remove selected/all queue entries.
- Save modes:
  - PDF file
  - CBZ file
  - multiple images
  - one merged image
- Folder structure toggles (per cartoon / per chapter).
- "High quality" mode (removes `type` query where applicable).
- Fan-translation download support (`language` + optional `teamVersion`).
- "Skip downloaded chapters" for bundled output modes.
- Progress and status reporting.
- Missing-image and unofficial-translation warning image generation.

## Project setup in Xcode

1. Create a new **iOS App** project in Xcode (SwiftUI lifecycle).
2. Copy all files from `KeaIOSApp/` into your Xcode target.
3. Ensure deployment target is iOS 16+ (for current APIs used).
4. Build and run on iPhone simulator/device.

## Notes

- This implementation keeps the same workflow and core downloader behavior from the WinForms app, adapted to iOS-native APIs (`SwiftUI`, `URLSession`, `PDFKit`, `FileManager`).
- Parsing HTML is done with regex-based extraction to avoid external dependencies.
