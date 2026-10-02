import 'package:flutter/painting.dart';

/// 디자인 토큰 `tokens/tokens.json`의 `color`와, 원본 템플릿에서 쓰는 보조 색.
///
/// 위젯에는 hex를 직접 쓰지 않고 여기 이름만 쓴다.
abstract final class AppColors {
  // tokens.json › color
  static const ink = Color(0xFF111111);
  static const paper = Color(0xFFFFFFFF);
  static const red = Color(0xFFE5402B);
  static const redTint = Color(0xFFFDECE9);
  static const surface = Color(0xFFF3F3F1);
  static const surfaceSoft = Color(0xFFF6F6F4);
  static const line = Color(0xFFF0F0EE);
  static const cardStroke = Color(0xFFEFEFEC);
  static const textMuted = Color(0xFF9A9A97);
  static const textFaint = Color(0xFFB5B5B2);
  static const textFainter = Color(0xFFCFCFCC);
  static const disabled = Color(0xFFCFCFCC);
  static const toggleOff = Color(0xFFDADAD7);
  static const kraft = Color(0xFFC9A06A);
  static const kraftLight = Color(0xFFD2AB72);
  static const kraftDark = Color(0xFFC29558);
  static const kraftTape = Color(0xFFEFE4CF);
  static const labelPaper = Color(0xFFF7F5F0);
  static const dim = Color(0x5C000000); // rgba(0,0,0,.36)

  // 원본 템플릿에서 쓰는 보조 색 (source/TapeletterApp.template.html)
  /// 부제·설명 글자 (`#8A8A87`)
  static const textSub = Color(0xFF8A8A87);

  /// 진한 보조 글자 (`#6E6E6B`)
  static const textSecondary = Color(0xFF6E6E6B);

  /// 꺼진 길이 표시·반복 아이콘 (`#C5C5C2`)
  static const textOff = Color(0xFFC5C5C2);

  /// 개수 표시 등 (`#A5A5A2`)
  static const textCount = Color(0xFFA5A5A2);

  /// 녹음 버튼 바깥 링 (`#E6E6E3`)
  static const recRing = Color(0xFFE6E6E3);

  /// 진행 바 트랙 (`#EEEEEC`)
  static const progressTrack = Color(0xFFEEEEEC);

  /// 즐겨찾기 별 (`#E3A92B`)
  static const star = Color(0xFFE3A92B);

  /// 카카오 노랑과 글자
  static const kakao = Color(0xFFFEE500);
  static const kakaoInk = Color(0xFF191600);

  /// Google 로그인 버튼 (브랜딩 가이드 라이트 테마: 흰 바탕, `#747775` 1px 테두리, `#1F1F1F` 글자)
  static const googleFill = Color(0xFFFFFFFF);
  static const googleStroke = Color(0xFF747775);
  static const googleInk = Color(0xFF1F1F1F);

  /// 시트 손잡이 (`#E3E3E0`)
  static const handle = Color(0xFFE3E3E0);

  /// 녹음 중 빨간 링 펄스 (`rgba(229,64,43,.35)`)
  static const recPulse = Color(0x59E5402B);

  /// 앱 바깥 배경 (`#EDEDEB`) — 프로토타입 폰 프레임 밖
  static const backdrop = Color(0xFFEDEDEB);

  // 소포 박스 (vSending)
  static const boxInside = Color(0xFFA87C44);
  static const flapTop = Color(0xFFC99E62);
  static const flapBottom = Color(0xFFBB8E52);
  static const flapTape = Color(0xFFE6D9C0);

  // 서랍 책꽂이 보기 (vShelf isShelf, emptyOn)
  static const shelfBoardTop = Color(0xFFFBF9F5);
  static const shelfBoardBottom = Color(0xFFF2EDE3);
  static const shelfPlank = Color(0xFFDDD3C2);
  static const shelfDash = Color(0xFFCFC6B5);

  // 서랍 · 도착한 소포 구역 (v10.2)
  /// 카드 바탕 (`#FBF9F5`) · 테두리 (`inset 0 0 0 1px #EFE4CF`) · 누른 행 (`#F5EEE2`)
  static const parcelCard = Color(0xFFFBF9F5);
  static const parcelStroke = Color(0xFFEFE4CF);
  static const parcelPressed = Color(0xFFF5EEE2);

  // 서랍 꽉 참 시트 (shFullOpen)
  /// 꽉 찬 선반 일러스트의 등 10개 (`foSpines`)
  static const fullSpines = [
    Color(0xFF1E1E1E),
    Color(0xFFC9A06A),
    Color(0xFFE5402B),
    Color(0xFF2B4A6F),
    Color(0xFF1E1E1E),
    Color(0xFFE8E2D6),
    Color(0xFFE5402B),
    Color(0xFFC9A06A),
    Color(0xFF2B4A6F),
    Color(0xFF1E1E1E),
  ];

  /// 등 오른쪽 그림자 (`inset -2px 0 0 rgba(0,0,0,.14)`)
  static const spineShade = Color(0x24000000);

  /// 칸별 보관 카드 구분선 (`#E8E8E5`)
  static const cardDivider = Color(0xFFE8E8E5);

  /// 검정 버튼 안 보조 글자 (`rgba(255,255,255,.7)`)
  static const paperMuted = Color(0xB3FFFFFF);

  // 테이프 메모 (shMemo, ⋯ 메뉴 메모 카드)
  /// 메모 입력칸·카드 바탕 (`#FBF9F5`)
  static const memoPaper = Color(0xFFFBF9F5);

  /// 메모 입력칸·카드 테두리 (`inset 0 0 0 1px #EFE8DB`)
  static const memoStroke = Color(0xFFEFE8DB);

  /// 메모 카드 글자 (`#3A3A38`)
  static const memoInk = Color(0xFF3A3A38);

  /// 스켈레톤 옅은 막대 (`#F4F4F2`)
  static const skeletonLight = Color(0xFFF4F4F2);

  // 소포 뜯기 오른쪽 반 (vParcel)
  static const kraftRightLight = Color(0xFFC9A066);
  static const kraftRightDark = Color(0xFFB98B4F);

  // 상점·마이 (vShop, vMy, 시트)
  /// 선물 아이콘 바탕 (`#F3E6E4`)
  static const giftTint = Color(0xFFF3E6E4);

  /// 서랍 넓히기 견본 (`#F0ECE4`)
  static const drawerSwatch = Color(0xFFF0ECE4);


  /// 탈퇴 시트 요약 구분선 (`#EDEDEA`)
  static const withdrawLine = Color(0xFFEDEDEA);

  /// 앱 안 푸시 배너 (`rgba(246,246,244,.98)`)
  static const pushBanner = Color(0xFAF6F6F4);

  /// 그림자·반투명 막의 바탕 (rgba(0,0,0,α)는 `black.withValues(alpha: α)`)
  static const black = Color(0xFF000000);

  /// 가리는 흰 막 (`rgba(255,255,255,.55)`) — 0개인 테이프
  static const lockVeil = Color(0x8CFFFFFF);
}
