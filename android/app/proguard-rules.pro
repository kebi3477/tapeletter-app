# 출시 빌드(R8)에서 Room이 리플렉션으로 만드는 생성 클래스(*_Impl)를 지우지 않게 한다.
# 없으면 WorkManager(Firebase·AdMob이 씀)가 앱 시작 때 WorkDatabase를 못 만들고 죽는다.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
