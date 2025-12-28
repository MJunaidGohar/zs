import 'package:hive/hive.dart';

/// ------------------------------------------------------
/// UserService
/// Saves and loads user info like name, class, and avatar (Hive)
/// ------------------------------------------------------

const String _userBox = "user";

/// Save user info (name, class, avatar)
Future<void> saveUserInfo({
  required String name,
  required String userClass,
  String? avatarPath, // optional avatar
}) async {
  final box = Hive.isBoxOpen(_userBox)
      ? Hive.box(_userBox)
      : await Hive.openBox(_userBox);

  await box.put('userName', name);
  await box.put('userClass', userClass);

  if (avatarPath != null) {
    await box.put('avatar', avatarPath);
  }
}

/// Load user info
Future<Map<String, String?>> loadUserInfo() async {
  final box = Hive.isBoxOpen(_userBox)
      ? Hive.box(_userBox)
      : await Hive.openBox(_userBox);

  String? name = box.get('userName') as String?;
  String? userClass = box.get('userClass') as String?;
  String? avatar = box.get('avatar') as String?;

  return {
    'name': name,
    'class': userClass,
    'avatar': avatar,
  };
}

/// Save avatar separately (optional)
Future<void> saveUserAvatar(String avatarPath) async {
  final box = Hive.isBoxOpen(_userBox)
      ? Hive.box(_userBox)
      : await Hive.openBox(_userBox);
  await box.put('avatar', avatarPath);
}

/// Load avatar separately
Future<String?> loadUserAvatar() async {
  final box = Hive.isBoxOpen(_userBox)
      ? Hive.box(_userBox)
      : await Hive.openBox(_userBox);
  return box.get('avatar') as String?;
}
