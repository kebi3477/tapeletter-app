/// logic.js `fmt`: 초 → `m:ss`.
String formatClock(num seconds) {
  final s = seconds.floor();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 날짜 → `MM.DD` (프로토타입 표기). 기기 시간대로 바꿔서 쓴다.
String formatMonthDay(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.month)}.${_two(l.day)}';
}

/// logic.js `at(x)`: 받은 테이프의 날짜 + 시·분 → `MM.DD HH:mm` (24시간, 기기 시간대).
/// 서랍·칸 목록, ⋯ 시트, 신고, 받은 테이프, 재생 화면 제목·목록, 친구 화면에 쓴다.
String formatMonthDayTime(DateTime d) {
  final l = d.toLocal();
  return '${formatMonthDay(l)} ${_two(l.hour)}:${_two(l.minute)}';
}
