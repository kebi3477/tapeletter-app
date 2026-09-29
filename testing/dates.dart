import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/utils/format.dart';

/// 초기 데이터(UTC 정오) 날짜를 기기 시간대의 `MM.DD HH:mm`으로 — 시험이 시간대에 묶이지 않게.
String at(int month, int day) => formatMonthDayTime(LocalStore.d(month, day));
