import '../../models/question.dart';

// Import all class barrels
import 'questions/9th/_all.dart' as ninth;
import 'questions/10th/_all.dart' as tenth;
import 'questions/11th/_all.dart' as eleventh;
import 'questions/12th/_all.dart' as twelve;


final Map<String, Map<String, dynamic>> questionsData = {
  "9th": {
    "Physics": ninth.physics9th,
    "Computer": ninth.computer9th,
    "Chemistry": ninth.chemistry9th,
  },
  "10th": {
    "Physics": tenth.physics10th,
    "Computer": tenth.computer10th,
    "Chemistry": tenth.chemistry10th,
  },
  "11th": {
    "Physics": eleventh.physics11th,
    "Computer": eleventh.computer11th,
    "Chemistry": eleventh.chemistry11th,
  },
  "12th": {
    "Computer": twelve.computer12th,
    "Chemistry": twelve.chemistry12th,
  },
};
