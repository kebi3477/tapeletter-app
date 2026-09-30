import '../../domain/models/blocked_user.dart';
import '../../domain/models/friend.dart';
import '../../domain/models/friend_tapes.dart';
import '../../domain/models/me.dart';
import '../../domain/models/recipient.dart';
import '../../domain/models/recording.dart';
import '../../domain/models/sent_tape.dart';
import '../../domain/models/shelf.dart';
import '../../domain/models/shop.dart';
import '../../domain/models/tape_audio.dart';
import '../../domain/models/tape_item.dart';
import '../../domain/models/tape_tag.dart';
import '../../domain/models/tape_type.dart';
import '../../domain/models/wallet.dart';
import 'delivery_dto.dart';
import 'friend_dto.dart';
import 'me_dto.dart';
import 'recording_dto.dart';
import 'shop_dto.dart';
import 'shelf_dto.dart';
import 'wallet_dto.dart';

/// 계약서 DTO → 앱 도메인 모델.

extension MeDtoMapper on MeDto {
  Me toDomain() => Me(
    id: id,
    name: name ?? '',
    credits: credits,
    owned: {
      for (final t in tapes)
        if (t.qty != null) TapeType.fromCode(t.tapeType): t.qty!,
    },
    drawer: DrawerSummary(
      stored: drawer.stored,
      cap: drawer.cap,
      full: drawer.full,
      unopenedCount: drawer.unopenedCount,
    ),
    receivedCount: stats.receivedCount,
    sentCount: stats.sentCount,
    friendCount: stats.friendCount,
    providers: providers,
    notificationsEnabled: notificationsEnabled,
  );

  /// `GET /users/me`의 보유 테이프 + `GET /wallet`의 광고 횟수
  Wallet toWallet(WalletDto wallet) => Wallet(
    credits: wallet.credits,
    owned: toDomain().owned,
    adsLeft: wallet.ads.remainingToday,
  );
}

extension FriendDtoMapper on FriendDto {
  Friend toDomain() => Friend(
    id: userId,
    name: displayName,
    originalName: name,
    nickname: nickname,
    starred: starred,
    lastAt: lastAt,
  );
}

extension ShelfItemDtoMapper on ShelfItemDto {
  TapeItem toDomain() => TapeItem(
    id: id,
    from: sender.displayName,
    senderName: sender.name,
    senderId: sender.userId,
    date: sentAt,
    type: TapeType.fromCode(tapeType),
    duration: Duration(milliseconds: durationMs),
    tag: TapeTag.fromCode(tag),
    opened: opened,
    viaLink: viaLink,
    groupId: groupId,
    memo: memo,
  );
}

extension ShelfDtoMapper on ShelfDto {
  Shelf toDomain() => Shelf(
    unsorted: unsorted.map((x) => x.toDomain()).toList(),
    groups: groups.map((g) => g.toDomain()).toList(),
    cap: cap,
  );
}

extension ShelfGroupDtoMapper on ShelfGroupDto {
  ShelfGroup toDomain() => ShelfGroup(
    id: id,
    name: name,
    items: items.map((x) => x.toDomain()).toList(),
  );
}

extension FriendTapesDtoMapper on FriendTapesDto {
  FriendTapes toDomain() => FriendTapes(
    friend: friend.toDomain(),
    items: [
      for (final x in items)
        FriendTape(item: x.toDomain(), where: x.groupName ?? '분류 안 함'),
    ],
    unopenedCount: unopenedCount,
  );
}

extension AudioUrlDtoMapper on AudioUrlDto {
  TapeAudio toDomain() => TapeAudio(
    url: url,
    expiresAt: expiresAt,
    duration: Duration(milliseconds: durationMs),
  );
}

extension RecordingDtoMapper on RecordingDto {
  Recording toDomain() => Recording(
    id: id,
    type: TapeType.fromCode(tapeType),
    duration: Duration(milliseconds: durationMs),
    status: recordingStatus(status),
    previewUrl: preview?.url,
  );
}

RecordingStatus recordingStatus(String s) => switch (s) {
  'uploading' => RecordingStatus.uploading,
  'processing' => RecordingStatus.processing,
  'ready' => RecordingStatus.ready,
  _ => RecordingStatus.failed,
};

extension SentTapeDtoMapper on SentTapeDto {
  SentTape toDomain() {
    final s = switch (status) {
      'link_pending' => SentStatus.linkPending,
      'link_expired' => SentStatus.linkExpired,
      'opened' => SentStatus.opened,
      _ => SentStatus.unopened,
    };
    return SentTape(
      id: id,
      status: s,
      // recipient.nickname → recipient.name → linkName → "새 친구"
      to: recipient?.displayName ?? linkName ?? Recipient.unnamed,
      date: sentAt,
      type: TapeType.fromCode(tapeType),
      link: share != null || linkName != null || status.startsWith('link_'),
      claimed: claimedAt != null || recipient != null,
      openedAt: openedAt,
      shareUrl: share == null ? null : Uri.parse(share!.url),
    );
  }
}

extension LedgerEntryDtoMapper on LedgerEntryDto {
  LedgerEntry toDomain() =>
      LedgerEntry(date: createdAt, reason: reason, amount: delta);
}

extension BlockedUserDtoMapper on BlockedUserDto {
  BlockedUser toDomain() =>
      BlockedUser(id: userId, name: displayName, blockedAt: blockedAt);
}

extension ProductsDtoMapper on ProductsDto {
  ShopCatalog toDomain() => ShopCatalog(
    tapes: [
      for (final t in tapes)
        TapeProduct(
          id: t.id,
          name: t.name,
          price: t.price,
          type: TapeType.fromCode(t.tapeType),
          qty: t.qty,
        ),
    ],
    drawer: [
      for (final d in drawer)
        DrawerProduct(id: d.id, name: d.name, price: d.price, slots: d.slots),
    ],
    packs: [
      for (final p in creditPacks)
        CreditPack(
          productId: p.productId,
          credits: p.credits,
          priceLabel: p.priceLabel,
        ),
    ],
    giftAmounts: giftAmounts,
  );
}

extension PurchaseResultDtoMapper on PurchaseResultDto {
  PurchaseResult toDomain() => PurchaseResult(
    credits: credits,
    owned: {
      for (final t in tapes)
        if (t.qty != null) TapeType.fromCode(t.tapeType): t.qty!,
    },
    stored: drawer.stored,
    cap: drawer.cap,
  );
}
