enum PuzzleMode {
  oneVsOne('1 vs 1'),
  twoVsTwo('2 vs 2'),
  vsAI('vs IA'),
  local('Local'),
  friends('Amigos');

  const PuzzleMode(this.displayName);
  final String displayName;

  static PuzzleMode fromString(String mode) {
    return PuzzleMode.values.firstWhere(
      (e) => e.displayName == mode || e.name == mode,
      orElse: () => PuzzleMode.local,
    );
  }
}
