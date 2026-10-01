# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

tapeletter 앱(옛 이름 cassette). 목소리를 15초·1분·3분짜리 카세트테이프에 녹음해 친구에게 소포로 보내고, 받은 테이프를 서랍에 칸별로 정리해 이어 듣는다. 테이프는 크레딧으로 사고, 크레딧은 광고 시청이나 결제로 얻는다.

- Flutter, iOS·Android. 번들 ID는 iOS·Android 모두 `com.kebi.tapeletter`
- API: `../tapeletter-api` (NestJS). 응답 스펙은 이 앱의 도메인 모델과 맞춘다
- 두 저장소에 공통으로 적용되는 아키텍처 결정은 `../ARCHITECTURE.md`에 있다 (저장소 바깥 파일)

## 디자인

- Claude Design 프로젝트: https://claude.ai/design/p/42baf543-407c-43b6-a96e-04d5997ef801 (`Tapeletter App.dc.html`)
- 핸드오프: `../design_handoff_cassette_app/` (저장소 바깥, 위 프로젝트에서 받은 v4). 읽는 순서는 그 폴더의 `README.md` → `docs/READING_THE_SOURCE.md` → `docs/BEHAVIOR.md` → `docs/DATA_MODEL.md`. **수치·문구·타이밍·상태 전이는 `source/TapeletterApp.logic.js`와 `source/TapeletterApp.template.html`이 정답이다.** README나 docs가 source와 다르면 source를 따른다. 추측하지 않는다
- 하이파이이고 기준 화면은 390×844다. 색·글자·간격·모서리·애니메이션·문구를 픽셀 단위로 맞춘다
- 토큰(`tokens/tokens.json`)은 `lib/ui/core/themes/`로 옮긴다. 위젯에 hex를 하드코딩하지 않는다. 글꼴은 SUIT 하나, 숫자는 tabular figures
- 아이콘·로고는 핸드오프 `assets/`의 SVG를 앱 `assets/`로 복사해 그대로 쓴다
- 프로토타입 실행본: `npx serve ../design_handoff_cassette_app/prototype`. Tweaks 패널의 `scene`/`failMode`로 v2 상태(로그인, 실패, 링크 오류 등)를 바로 볼 수 있다
- 테이프, 미니 테이프, 소포 박스, 탭 아이콘은 원본이 CSS 도형이다. 같은 치수의 `CustomPainter`로 만든다

프로토타입과 다르게 구현할 것:

- 가짜 250ms 타이머 → 실제 녹음(`record`)과 재생(`just_audio`)
- 데모용 재생 길이 `DUR` → 실제 파일 길이
- 공유·결제·광고 토스트 목업 → 실제 연동
- 고정 날짜 `09.25` → 실제 날짜

## 폴더 구조 — 공식 앱 아키텍처 가이드

https://docs.flutter.dev/app-architecture 의 구조와 MVVM을 따른다. 다른 구조(feature-first 등)로 바꾸지 않는다.

```
lib/
├── config/                  # 환경 설정, 의존성 등록
├── data/
│   ├── repositories/        # <이름>_repository.dart
│   ├── services/            # API 클라이언트, 녹음, 재생, 결제 등 외부 접점
│   └── model/               # API 모델 (DTO)
├── domain/
│   └── models/              # 앱 도메인 모델
├── routing/
├── ui/
│   ├── core/
│   │   ├── ui/              # 공용 위젯 (TapeWidget, MiniTape, ParcelBox, 시트, 토스트)
│   │   └── themes/
│   └── <기능>/              # record, shelf, player, shop, my, friend
│       ├── view_model/
│       └── widgets/         # <기능>_screen.dart + 하위 위젯
├── utils/
└── main.dart
test/                        # lib/와 같은 구조
testing/                     # 가짜 repository·service (프로토타입 초기 데이터)
```

- 상태 관리: ViewModel(`ChangeNotifier`) + `provider`
- 라우팅: `go_router` (탭 4개는 `StatefulShellRoute`)
- 녹음 흐름은 phase enum 하나로 관리한다: `idle → rec → confirm → pick → label → sending → sent`
- 반복 모드 "순서대로 / 전체 반복 / 한 개 반복"은 `LoopMode.off / all / one`에 대응한다

## 설정

카카오·Apple(iOS)·Google(Android) 로그인, Firebase 푸시, 유니버설 링크 도메인(`ios/Flutter/Env.xcconfig`, dart-define), AdMob·IAP, `FAIL_MODE` 등 실행 설정은 `docs/SETUP.md`에 있다. Firebase 설정 파일(`GoogleService-Info.plist`, `google-services.json`, `firebase_options.dart`)은 커밋하지 않는다.

## 명령어

```bash
flutter run
flutter analyze
flutter test
flutter test --tags server --dart-define=API_BASE_URL=http://localhost:3000/api   # ../tapeletter-api 서버를 띄운 상태에서
flutter build ios --debug --no-codesign
flutter build apk --debug
flutter build appbundle --release --dart-define-from-file=dart_defines/prod.json   # 출시용, android/key.properties 필요
flutter build ipa --release --dart-define-from-file=dart_defines/prod.json
```

변경을 마치면 analyze, test, iOS·Android 빌드를 확인한다. 맥 디스크 여유가 적으니(10GB대) 빌드 뒤 `rm -rf build`로 지운다.

출시 서명: `android/key.properties`(커밋 안 함)가 있으면 release를 업로드 키로 서명한다. 원본 키·비밀번호는 `~/private_keys/tapeletter/`에 있다.

## 커밋

- **커밋 메시지는 한 줄만 쓴다.** 본문이나 트레일러(Co-Authored-By 등)를 붙이지 않는다
- 접두어를 붙인다: `feat:` `fix:` `refactor:` `style:` `docs:` `test:` `chore:`
- 메시지 본문은 한국어로 쓴다. 예: `feat: 녹음 화면 테이프 캐러셀 추가`
