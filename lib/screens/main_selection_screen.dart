// main_selection_screen.dart

import 'package:flutter/material.dart';
import '../widgets/top_bar_scaffold.dart';
import '../screens/test_screen.dart';
import '../screens/learn_screen.dart';
import '../data/sample_question.dart';
import '../services/progress_service.dart'; // ✅ For unit progress
import '../utils/string_extensions.dart';

/// ------------------------------------------------------
/// MainSelectionScreen
/// - User selects Class → Subject → Unit
/// - Then chooses Test or Learn mode
/// - Units are highlighted if completed
/// ------------------------------------------------------
class MainSelectionScreen extends StatefulWidget {
  const MainSelectionScreen({super.key});

  @override
  _MainSelectionScreenState createState() => _MainSelectionScreenState();
}

class _MainSelectionScreenState extends State<MainSelectionScreen> {
  String? selectedClass;
  String? selectedSubject;
  String? selectedUnit;

  /// Store completion status of units
  Map<String, bool> unitCompletion = {};

  /// Build a unique unit ID (class+subject+unit)
  String _unitKey(String unit) =>
      "${selectedClass}_${selectedSubject}_$unit";

  /// Get available subjects for selected class dynamically
  List<String> getSubjectsForClass() {
    if (selectedClass == null) return [];
    return questionsData[selectedClass!]!.keys.toList();
  }

  /// Get available units for selected class + subject dynamically
  List<String> getUnitsForSubject() {
    if (selectedClass == null || selectedSubject == null) return [];
    return questionsData[selectedClass!]![selectedSubject!]!.keys.toList();
  }

  /// Load unit progress for currently selected subject
  Future<void> _loadUnitProgress() async {
    if (selectedClass == null || selectedSubject == null) return;

    final units = getUnitsForSubject();
    Map<String, bool> newCompletion = {};

    for (String unit in units) {
      bool completed = await loadUnitProgress(_unitKey(unit)); // ✅ unique key
      newCompletion[unit] = completed;
    }

    setState(() {
      unitCompletion = newCompletion;
    });
  }

  /// Navigate to Test Screen
  void goToTest() {
    if (selectedClass != null &&
        selectedSubject != null &&
        selectedUnit != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TestScreen(
            selectedClass: selectedClass!,
            selectedCategory: "MCQ",
            selectedSubject: selectedSubject!,
            selectedQuestionType: "MCQs",
            selectedUnit: selectedUnit!,
          ),
        ),
      ).then((_) {
        _loadUnitProgress(); // Refresh progress when returning
      });
    }
  }

  /// Navigate to Learn Screen
  void goToLearn() {
    if (selectedClass != null &&
        selectedSubject != null &&
        selectedUnit != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LearnScreen(
            selectedClass: selectedClass!,
            selectedCategory: "Learn",
            selectedSubject: selectedSubject!,
            selectedUnit: selectedUnit!,
          ),
        ),
      ).then((_) {
        _loadUnitProgress(); // Refresh progress when returning
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TopBarScaffold(
      title: 'Zarori Sawal',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// -------------------------------
            /// Class Selection
            /// -------------------------------
            const Text(
              "Select Class",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedClass,
              hint: const Text("Tap to Select"),
              items: questionsData.keys
                  .map((cls) => DropdownMenuItem(
                value: cls,
                child: Text(cls),
              ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedClass = val;
                  selectedSubject = null; // Reset dependent fields
                  selectedUnit = null;
                  unitCompletion.clear();
                });
              },
            ),
            const SizedBox(height: 16),

            /// -------------------------------
            /// Subject Selection
            /// -------------------------------
            const Text(
              "Select Subject",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedSubject,
              hint: const Text("Tap to Select"),
              items: getSubjectsForClass()
                  .map((subj) => DropdownMenuItem(
                value: subj,
                child: Text(subj),
              ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedSubject = val;
                  selectedUnit = null;
                  unitCompletion.clear();
                });
                _loadUnitProgress(); // ✅ Load progress on subject change
              },
            ),
            const SizedBox(height: 16),

            /// -------------------------------
            /// Unit Selection (with completion)
            /// -------------------------------
            const Text(
              "Select Unit",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedUnit,
              hint: const Text("Tap to Select"),
              items: getUnitsForSubject()
                  .map((unit) {
                bool completed = unitCompletion[unit] ?? false;
                return DropdownMenuItem(
                  value: unit,
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: completed ? Colors.lightGreen
                        : Theme.of(context).textTheme.bodyLarge?.color, // auto adapts
                      fontWeight:
                      completed ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedUnit = val;
                });
              },
            ),
            const SizedBox(height: 32),

            /// -------------------------------
            /// Buttons for Test or Learn Mode
            /// -------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: goToTest,
                  child: const Padding(
                    padding:
                    EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Text("Test Mode",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                ElevatedButton(
                  onPressed: goToLearn,
                  child: const Padding(
                    padding:
                    EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Text("Study Mode",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 70),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: Colors.grey),
                children: [
                  TextSpan(
                      text: "For Consultation",
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                ],
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: Colors.grey),
                children: [
                  TextSpan(
                      text: "WhatsApp: 0307-7763195",
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
