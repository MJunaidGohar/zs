// lib/services/avatar_image_service.dart
// Service for handling camera and gallery image picking for avatars

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

/// Result class for image picking operations
class AvatarImageResult {
  final String? filePath;
  final String? error;
  final bool isSuccess;

  const AvatarImageResult._({
    this.filePath,
    this.error,
    required this.isSuccess,
  });

  factory AvatarImageResult.success(String filePath) {
    return AvatarImageResult._(filePath: filePath, isSuccess: true);
  }

  factory AvatarImageResult.failure(String error) {
    return AvatarImageResult._(error: error, isSuccess: false);
  }
}

/// Service for managing avatar image selection from camera or gallery
class AvatarImageService {
  static final AvatarImageService _instance = AvatarImageService._internal();
  factory AvatarImageService() => _instance;
  AvatarImageService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Pick image from camera
  Future<AvatarImageResult> pickFromCamera() async {
    try {
      // Check camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        return AvatarImageResult.failure('Camera permission denied');
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (photo == null) {
        return AvatarImageResult.failure('No image captured');
      }

      return await _processAndSaveImage(photo);
    } catch (e) {
      return AvatarImageResult.failure('Camera error: $e');
    }
  }

  /// Pick image from gallery
  Future<AvatarImageResult> pickFromGallery() async {
    try {
      // Check storage permission for older Android versions
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          // Try photos permission for newer versions
          final photosStatus = await Permission.photos.request();
          if (!photosStatus.isGranted) {
            return AvatarImageResult.failure('Storage permission denied');
          }
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) {
        return AvatarImageResult.failure('No image selected');
      }

      return await _processAndSaveImage(image);
    } catch (e) {
      return AvatarImageResult.failure('Gallery error: $e');
    }
  }

  /// Process and save image to app directory
  Future<AvatarImageResult> _processAndSaveImage(XFile sourceFile) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String avatarsDir = path.join(appDir.path, 'avatars');

      // Create avatars directory if it doesn't exist
      await Directory(avatarsDir).create(recursive: true);

      // Generate unique filename
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = path.extension(sourceFile.path);
      final String filename = 'avatar_$timestamp$extension';
      final String destPath = path.join(avatarsDir, filename);

      // Copy file to app directory
      final File source = File(sourceFile.path);
      await source.copy(destPath);

      return AvatarImageResult.success(destPath);
    } catch (e) {
      return AvatarImageResult.failure('Failed to save image: $e');
    }
  }

  /// Delete custom avatar file
  Future<bool> deleteCustomAvatar(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting avatar: $e');
      return false;
    }
  }

  /// Check if a path is a custom avatar (not an asset)
  static bool isCustomAvatar(String path) {
    return !path.startsWith('assets/') && 
           (path.startsWith('/') || path.contains('avatars'));
  }

  /// Show image source selection dialog
  static Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Choose Photo Source',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: Colors.blue,
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: Colors.green,
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget for image source option
class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
