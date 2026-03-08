# Certificate Assets

This folder contains the images used for generating certificate PDFs.

## Required Files

Place the following files in this directory:

1. **logo.png** - Junaid Studio logo (transparent background recommended)
   - Size: ~200x100 pixels
   - Format: PNG with transparency

2. **signature.png** - M Junaid Gohar's signature
   - Size: ~300x100 pixels
   - Format: PNG with transparency

3. **background.png** - Certificate background template
   - Size: A4 Landscape (842x595 pixels at 72 DPI)
   - Format: PNG
   - Should include: Corner designs, ribbon/badge on the right side

## Certificate Design

The certificate includes:
- Certificate of Achievement title
- User name (from profile)
- Topic name (selected topic)
- Current date
- Junaid Studio logo (bottom left)
- Signature with name (bottom right)

## Technical Notes

- Images are loaded using Flutter's `rootBundle.load()`
- Ensure files are properly added to `pubspec.yaml` assets section:
  ```yaml
  assets:
    - assets/certificate/
  ```
- The PDF generation uses the `pdf` package to create A4 landscape certificates
