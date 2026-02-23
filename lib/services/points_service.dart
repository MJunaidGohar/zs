import 'package:hive/hive.dart';
import 'hive_service.dart';

class PointsService {
  final Box<int> _box = HiveService.pointsBox;
  static const String _key = 'user_points';

  Future<int> getPoints() async {
    return _box.get(_key, defaultValue: 0) ?? 0;
  }

  Future<void> addPoints(int points) async {
    int currentPoints = _box.get(_key, defaultValue: 0) ?? 0;
    await _box.put(_key, currentPoints + points);
  }

  Future<void> resetPoints() async {
    await _box.put(_key, 0);
  }
}
