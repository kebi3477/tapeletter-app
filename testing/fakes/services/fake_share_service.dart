import 'package:tapeletter_app/data/services/share_service.dart';

/// 공유를 채널별로 기록한다.
class FakeShareService implements ShareService {
  FakeShareService({this.result = true});

  /// 공유 시트에서 공유했는지(true) 닫았는지(false), 카카오톡·문자 앱을 열었는지
  bool result;

  /// 시스템 공유 시트 본문
  final List<String> shared = [];
  final List<TapeLinkMessage> kakao = [];
  final List<TapeLinkMessage> sms = [];

  @override
  Future<bool> shareText(String text) async {
    shared.add(text);
    return result;
  }

  @override
  Future<bool> shareKakao(TapeLinkMessage message) async {
    kakao.add(message);
    return result;
  }

  @override
  Future<bool> shareSms(TapeLinkMessage message) async {
    sms.add(message);
    return result;
  }
}
