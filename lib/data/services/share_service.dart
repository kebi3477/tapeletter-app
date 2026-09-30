import 'dart:io';

import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 링크로 보낸 테이프의 공유 내용
class TapeLinkMessage {
  const TapeLinkMessage({
    required this.senderName,
    required this.tapeName,
    required this.url,
  });

  /// 보낸 사람(나) 이름
  final String senderName;

  /// `15초` · `1분` · `3분`
  final String tapeName;

  /// `https://{PUBLIC_HOST}/t/{token}` (서버의 `shareUrl`)
  final Uri url;

  /// 카드 제목 (`design_handoff_kakao_share` 카카오 피드 템플릿). 이름이 없으면 "누군가"
  String get title => senderName.trim().isEmpty
      ? '누군가 목소리 테이프를 보냈어요'
      : '${senderName.trim()}님이 목소리 테이프를 보냈어요';

  /// 링크별 카드 이미지 `https://{host}/t/{token}/kakao.png` (800×400)
  Uri get imageUrl => url.replace(
    path:
        '${url.path.endsWith('/') ? url.path.substring(0, url.path.length - 1) : url.path}/kakao.png',
  );

  /// 문자·공유 시트 본문
  String get text => '$title $url';
}

/// 공유 — 시스템 공유 시트, 카카오톡, 문자.
/// 카카오톡·문자는 앱을 열었는지만 알 수 있다(보냈는지는 알려 주지 않는다).
abstract class ShareService {
  /// 시스템 공유 시트. 공유했으면 true, 사용자가 닫았으면 false.
  Future<bool> shareText(String text);

  /// 카카오톡으로 테이프 링크 보내기. 카카오톡(또는 웹 공유 페이지)을 열었으면 true.
  Future<bool> shareKakao(TapeLinkMessage message);

  /// 문자 앱을 본문을 채운 채 연다. 열었으면 true.
  /// 문자 앱을 열 수 없으면 시스템 공유 시트로 대신한다.
  Future<bool> shareSms(TapeLinkMessage message);
}

class SystemShareService implements ShareService {
  SystemShareService({required this.kakaoNativeAppKey});

  /// 카카오 네이티브 앱 키. 비어 있으면 카카오톡 대신 공유 시트를 연다.
  final String kakaoNativeAppKey;
  bool _kakaoReady = false;

  @override
  Future<bool> shareText(String text) async {
    final result = await SharePlus.instance.share(ShareParams(text: text));
    return result.status != ShareResultStatus.dismissed;
  }

  /// 카카오톡 공유 기본 템플릿(콘솔 템플릿 없이 코드로) — `design_handoff_kakao_share`
  /// README의 카카오 피드 템플릿: 링크별 이미지(800×400), 제목·설명, 버튼 "테이프 듣기".
  /// 링크 도메인은 카카오 콘솔 > 플랫폼 > Web 사이트 도메인에 등록돼 있어야 한다.
  static FeedTemplate templateOf(TapeLinkMessage m) {
    final link = Link(webUrl: m.url, mobileWebUrl: m.url);
    return FeedTemplate(
      content: Content(
        title: m.title,
        description: '${m.tapeName} 테이프 · 탭해서 소포를 뜯어보세요',
        imageUrl: m.imageUrl,
        imageWidth: 800,
        imageHeight: 400,
        link: link,
      ),
      buttons: [Button(title: '테이프 듣기', link: link)],
    );
  }

  @override
  Future<bool> shareKakao(TapeLinkMessage message) async {
    if (kakaoNativeAppKey.isEmpty) return shareText(message.text);
    try {
      if (!_kakaoReady) {
        await KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
        _kakaoReady = true;
      }
      final template = templateOf(message);
      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        await ShareClient.instance.shareDefault(template: template);
        return true;
      }
      // 카카오톡이 없으면 웹 공유(카카오 계정 로그인 후 보내기)를 브라우저로
      final web = await WebSharerClient.instance.makeDefaultUrl(
        template: template,
      );
      return await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      return shareText(message.text);
    }
  }

  /// 문자 앱 주소 — iOS는 `sms:&body=`, Android는 `sms:?body=` (받는 사람 없이 본문만)
  static Uri smsUri(String body, {required bool ios}) =>
      Uri.parse('sms:${ios ? '&' : '?'}body=${Uri.encodeComponent(body)}');

  @override
  Future<bool> shareSms(TapeLinkMessage message) async {
    try {
      final opened = await launchUrl(
        smsUri(message.text, ios: Platform.isIOS),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return true;
    } catch (_) {}
    return shareText(message.text);
  }
}
