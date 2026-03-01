class TimeUtils {
  TimeUtils._();

  static String formatSeconds(int value) {
    final int minutes = value ~/ 60;
    final int seconds = value % 60;
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }
}
