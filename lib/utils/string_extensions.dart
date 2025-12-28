extension IgnoreCase on String? {
  bool equalsIgnoreCase(String other) {
    return (this ?? '').toLowerCase() == other.toLowerCase();
  }
}
