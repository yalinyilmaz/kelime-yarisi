import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/presentation/cubit/room_lobby_cubit.dart';
import 'package:kelime_yarisi/features/room/presentation/widgets/room_code_card.dart';

import 'app_router_test.dart' show FakeLobbyService;
import 'game_cubit_test.dart' show testRoom;

void main() {
  testWidgets(
    'copy code then share invitation, anchor to the button and ignore duplicate taps',
    (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <String>[];
      Map<Object?, Object?>? params;
      String? clipboard;
      var failShare = false;
      var failCopy = false;
      final shareGate = Completer<String>();
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          if (failCopy) throw PlatformException(code: 'copy_failed');
          calls.add('copy');
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        params = call.arguments as Map<Object?, Object?>;
        if (failShare) throw PlatformException(code: 'share_failed');
        return shareGate.future;
      });
      final service = FakeLobbyService();
      final room = testRoom().copyWith(status: RoomStatus.lobby);
      final cubit = RoomLobbyCubit(service, room);
      addTearDown(() async {
        if (!shareGate.isCompleted) shareGate.complete('');
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(channel, null);
        await cubit.close();
        await service.disposeStreams();
      });
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Center(child: RoomCodeCard(room: room)),
            ),
          ),
        ),
      );
      final button = find.byTooltip('Oda kodunu kopyala ve davet paylaş');
      final rect = tester.getRect(button);
      await tester.tap(button);
      await tester.pump();
      expect(calls, ['copy', 'share']);
      expect(clipboard, room.code);
      expect(
        params!['text'],
        'Kelime Yarışı odama katıl!\nhttps://kelime-yarisi-yalin.web.app/invite/${room.code}\nOda kodu: ${room.code}',
      );
      expect(params!['originX'], rect.left);
      expect(params!['originY'], rect.top);
      expect(params!['originWidth'], rect.width);
      expect(params!['originHeight'], rect.height);
      await tester.tap(button);
      await tester.pump();
      expect(calls, ['copy', 'share']);
      shareGate.complete(
        '',
      ); // Cancelling the native sheet still leaves a copied code.
      await tester.pumpAndSettle();
      expect(clipboard, room.code);
      expect(cubit.state.errorMessage, isNull);

      failShare = true;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(clipboard, room.code);
      expect(
        cubit.state.errorMessage,
        'Oda kodu kopyalandı; paylaşım menüsü açılamadı.',
      );
      final shares = calls.where((call) => call == 'share').length;
      failCopy = true;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls.where((call) => call == 'share'), hasLength(shares));
      expect(cubit.state.errorMessage, 'Oda kodu kopyalanamadı. Tekrar dene.');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
