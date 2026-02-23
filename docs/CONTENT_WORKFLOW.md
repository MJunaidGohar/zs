# Content Management Workflow

## Overview

This document describes the professional workflow for managing content data in the Zaroori Sawal app using **Google Sheets** as the single source of truth.

## Architecture

```
Google Sheets (Source of Truth)
         ↓
[Build-Time Conversion via gsheet_to_json.dart]
         ↓
JSON Files (assets/content/)
         ↓
[App Runtime]
         ↓
ContentAvailabilityService → ContentLoaderService → QuestionService → UI
```

## Current State

### Working Content (JSON - 440 Questions)
All content is now managed via Google Sheets and converted to JSON:

| Topic | Levels | Subtopics | Questions |
|-------|--------|-----------|-----------|
| **English** | Basic, Intermediate, Advanced, Pro Master | Learning, Speaking, Writing, Listening | 80 |
| **Computer** | Basic, Intermediate, Advanced, Pro Master | Basics, MS Office | 40 |
| **Digital Marketing** | Basic, Intermediate, Advanced, Pro Master | Google Ads, Meta Ads | 40 |
| **Web Development** | Basic, Intermediate, Advanced, Pro Master | Wix, Shopify, WordPress | 60 |
| **Total** | | | **440** |

### Google Sheets Source
Master Sheet: https://docs.google.com/spreadsheets/d/1zkYzx9K4xz8RXCrxbUEaFRG6IEnqyAs007-Zv_H-Blg
- **Study Tab**: Flashcard questions (question + answer)
- **Test Tab**: MCQ questions (question + options A-D + correct_option)

**Note**: Excel files have been removed. All content is now managed via Google Sheets.

## Data Format

### JSON Structure
Each content file is an array of question objects:

```json
[
  {
    "topic": "English",
    "level": "Basic",
    "subtopic": "Speaking",
    "question": "How do you greet someone?",
    "answer": "Say 'Hello' with a smile.",
    "option_a": "Hello",
    "option_b": "Goodbye",
    "option_c": "Maybe",
    "option_d": "Nothing",
    "correct_option": "A"
  }
]
```

### CSV Structure
Same data in CSV format:
```csv
topic,level,subtopic,question,answer,option_a,option_b,option_c,option_d,correct_option
English,Basic,Speaking,How do you greet someone?,Say 'Hello' with a smile.,Hello,Goodbye,Maybe,Nothing,A
```

## File Organization

Content is organized hierarchically:
```
assets/content/
  {topic}/
    {level}/
      {subtopic}/
        study.json    (Short questions for Study mode)
        test.json     (MCQs for Test mode)
```

Examples:
- `english/basic/speaking/study.json`
- `english/basic/speaking/test.json`
- `youtube/basic/shorts/study.json`
- `youtube/intermediate/long_videos/test.json`

## How to Add/Update Content

### Option 1: Google Sheets (RECOMMENDED - Primary Workflow)

All content is managed through Google Sheets. This is the professional, collaborative approach.

**Setup:**
1. Access the master sheet: https://docs.google.com/spreadsheets/d/1zkYzx9K4xz8RXCrxbUEaFRG6IEnqyAs007-Zv_H-Blg
2. Ensure it's shared as "Anyone with link can VIEW"

**Sheet Structure:**
- **Study Tab**: Questions for flashcard/study mode
  - Columns: `topic | level | subtopic | question | answer`
- **Test Tab**: Questions for MCQ/test mode  
  - Columns: `topic | level | subtopic | question | option_a | option_b | option_c | option_d | correct_option`

**Workflow:**
1. Edit content in Google Sheets (Study or Test tab)
2. Run converter to download and generate JSON:
   ```bash
   dart run tool_scripts/gsheet_to_json.dart
   ```
3. Validate generated files:
   ```bash
   dart run tool_scripts/validate_json.dart
   ```
4. Build the app:
   ```bash
   flutter build apk
   ```

### Option 2: Direct JSON Files (For Quick Fixes)

For small, urgent updates without editing the Google Sheet:

1. Edit files directly in `assets/content/{topic}/{level}/{subtopic}/`
2. Validate: `dart run tool_scripts/validate_json.dart`
3. Build: `flutter build apk`

**Note**: Changes will be overwritten next time you run the Google Sheets converter. Always update the Google Sheet as the source of truth.

### Option 3: Build Script (For CI/CD)

Create a build script that automates the workflow:

```bash
#!/bin/bash
# build.sh

echo "Converting Google Sheets to JSON..."
dart run tool_scripts/gsheet_to_json.dart

echo "Validating JSON..."
dart run tool_scripts/validate_json.dart

echo "Building APK..."
flutter build apk

echo "Done!"
```

## Services

### ContentLoaderService
- **Purpose**: Load questions from JSON assets
- **Location**: `lib/services/content_loader_service.dart`
- **Features**:
  - JSON asset loading with caching
  - Automatic file detection
  - Error handling with user-friendly messages

### ContentAvailabilityService
- **Purpose**: Detect which content combinations exist
- **Location**: `lib/services/content_availability_service.dart`
- **Features**:
  - Scans assets at startup
  - Filters UI to only show available content
  - Provides content statistics

### QuestionService
- **Purpose**: Main interface for question operations
- **Location**: `lib/services/question_service.dart`
- **Uses**: ContentLoaderService for asset loading

## UI Behavior

The `MainSelectionScreen` will:
1. Show loading indicator while scanning content
2. Only display topics that have content
3. Only display levels that have content for selected topic
4. Only display subtopics that have content for selected topic+level
5. Disable action buttons if no valid combination is selected

## Adding New Topic/Level/Subtopic

To add a completely new topic:

1. Create the folder structure:
   ```bash
   mkdir -p assets/content/{new_topic}/{level}/{subtopic}
   ```

2. Add JSON files:
   - `study.json` for Study mode
   - `test.json` for Test mode

3. Update `QuestionService.topics` list (optional - for static lists)

4. Rebuild and deploy

The app will automatically detect and display the new content.

## Troubleshooting

### Content Not Showing
- Check file exists at correct path
- Verify JSON syntax is valid
- Check `pubspec.yaml` includes the assets
- Look at app logs for file loading errors

### Empty Questions
- Ensure `question` field is not empty
- Verify file encoding is UTF-8
- Check for proper JSON array format

### Build Issues
- Run `flutter clean` then `flutter pub get`
- Verify assets are declared in `pubspec.yaml`
- Check for syntax errors in JSON files

## Future Improvements

1. **Online Sync**: Add cloud-based content updates without rebuild
2. **Content Editor**: In-app content management UI
3. **Versioning**: Track content versions and updates
4. **Analytics**: Track which questions are most/least effective
