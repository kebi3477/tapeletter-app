import 'package:flutter_test/flutter_test.dart';
import 'package:tapeletter_app/data/services/share_service.dart';

void main() {
  final m = TapeLinkMessage(
    senderName: '민경',
    tapeName: '1분',
    url: Uri.parse('https://tapeletter.lab241.com/t/8F2K'),
  );

  test('문자 주소: iOS sms:&body=, Android sms:?body=, 본문은 URI 인코딩', () {
    expect(
      SystemShareService.smsUri(m.text, ios: true).toString(),
      'sms:&body=%EB%AF%BC%EA%B2%BD%EB%8B%98%EC%9D%B4%20%ED%85%8C%EC%9D%B4%ED%94%84%EB%A5%BC%20%EB%B3%B4%EB%83%88%EC%96%B4%EC%9A%94%20https%3A%2F%2Ftapeletter.lab241.com%2Ft%2F8F2K',
    );
    expect(
      SystemShareService.smsUri('a b&c', ios: false).toString(),
      'sms:?body=a%20b%26c',
    );
    expect(m.text, '민경님이 테이프를 보냈어요 https://tapeletter.lab241.com/t/8F2K');
  });

  test('카카오톡 기본 템플릿: 피드(링크 페이지 og와 같은 제목·이미지) + 테이프 듣기 버튼', () {
    final json = SystemShareService.templateOf(m).toJson();
    expect(json['object_type'], 'feed');
    final content = json['content'] as Map;
    expect(content['title'], '민경님이 테이프를 보냈어요');
    expect(content['description'], '1분 테이프');
    expect(
      content['image_url'],
      'https://tapeletter.lab241.com/static/og-image.png',
    );
    final link = content['link'] as Map;
    expect(link['web_url'], 'https://tapeletter.lab241.com/t/8F2K');
    expect(link['mobile_web_url'], 'https://tapeletter.lab241.com/t/8F2K');
    final button = (json['buttons'] as List).single as Map;
    expect(button['title'], '테이프 듣기');
  });
}
