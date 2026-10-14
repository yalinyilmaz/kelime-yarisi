import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/presentation/pages/game_page.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';

import 'game_cubit_test.dart' show FakeRoomService, testRoom;

void main() {
  testWidgets(
    'Game fits a narrow screen with keyboard, accepts answer, and displays live scores',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeRoomService();
      final room = testRoom().copyWith(
        startsAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
      );
      await tester.pumpWidget(
        RepositoryProvider<FirebaseRoomService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: GamePage(room: room),
          ),
        ),
      );
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pump();
      expect(find.text('SORU 1 / 7'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'kapı');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(service.saves.single.score, 400);
      await tester.scrollUntilVisible(
        find.text('SORU 2 / 7'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('SORU 2 / 7'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      tester.view.resetViewInsets();
      await tester.pump();
      service.rooms.add(
        room.copyWith(
          progress: {
            'guest': service.saves.last,
            'host': const GameProgress(
              questionIndex: 1,
              wrongCount: 1,
              score: -400,
            ),
          },
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('CANLI PUANLAR'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('-400'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.disposeStreams();
    },
  );

  testWidgets(
    'Equal results share a rank and final state removes answer controls',
    (tester) async {
      final service = FakeRoomService();
      final progress = const GameProgress(
        questionIndex: 7,
        correctCount: 7,
        score: 4900,
        finished: true,
      );
      final room = testRoom(progress: {'host': progress, 'guest': progress})
          .copyWith(
            startsAtMs: DateTime.now().millisecondsSinceEpoch - 121000,
            status: RoomStatus.results,
          );
      await tester.pumpWidget(
        RepositoryProvider<FirebaseRoomService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: GamePage(room: room),
          ),
        ),
      );
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Yarışma tamamlandı'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('SONUÇLAR'), 200);
      expect(find.text('1'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.disposeStreams();
    },
  );
}
