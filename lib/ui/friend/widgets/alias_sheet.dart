import 'package:flutter/material.dart';

import '../../../domain/models/friend.dart';
import '../../core/ui/text_limits.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/app_sheet.dart';
import '../../core/ui/buttons.dart';

/// 별명 최대 글자 수 (계약서: 최대 10자)
const aliasMax = 10;

/// 친구 별명 (`shAlias`) — 나에게만 보이는 이름. 비우면 원래 이름으로 보인다.
/// [onSave]에는 앞뒤 공백을 뺀 값(빈 문자열이면 지우기)을 넘긴다.
Future<void> showAliasSheet(
  BuildContext context, {
  required Friend friend,
  required ValueChanged<String> onSave,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheet) => _AliasForm(friend: friend, onSave: onSave),
  );
}

class _AliasForm extends StatefulWidget {
  const _AliasForm({required this.friend, required this.onSave});

  final Friend friend;
  final ValueChanged<String> onSave;

  @override
  State<_AliasForm> createState() => _AliasFormState();
}

class _AliasFormState extends State<_AliasForm> {
  late final TextEditingController _draft = TextEditingController(
    text: widget.friend.nickname ?? '',
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop();
    widget.onSave(_draft.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.friend.originalName;
    final n = _draft.text.characters.length;
    const underline = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.ink, width: 2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$name님의 별명', style: AppText.suit(800, 20, letterSpacingEm: -.01)),
        const SizedBox(height: 6),
        Text(
          '나에게만 보여요. $name님에게는 보이지 않아요',
          style: AppText.suit(500, 14, height: 1.55, color: AppColors.textSub),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: TextField(
            controller: _draft,
            autofocus: true,
            style: AppText.suit(800, 22),
            cursorColor: AppColors.ink,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(), // Enter
            inputFormatters: [maxCharacters(aliasMax)],
            decoration: InputDecoration(
              hintText: name,
              hintStyle: AppText.suit(800, 22, color: AppColors.textFaint),
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: underline,
              focusedBorder: underline,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '비우면 원래 이름으로 보여요',
                style: AppText.suit(
                  500,
                  12.5,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$n/$aliasMax',
              style: AppText.suit(
                600,
                12.5,
                height: 1.5,
                tabularNums: true,
                color: n >= aliasMax ? AppColors.red : AppColors.textFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AppButton(label: '저장', onTap: _save),
      ],
    );
  }
}

/// 친구 이름 + (별명이 있으면) 작은 회색 원래 이름 (`f.name` + `f.orig`)
class FriendNameLine extends StatelessWidget {
  const FriendNameLine({super.key, required this.friend, required this.style});

  final Friend friend;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final orig = friend.originalHint;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            friend.name,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (orig != null) ...[
          const SizedBox(width: 6),
          Text(
            orig,
            maxLines: 1,
            style: AppText.suit(500, 12.5, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
