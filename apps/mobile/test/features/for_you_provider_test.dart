import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/features/for_you/for_you_data.dart';
import 'package:miruyo/features/list/list_data.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('For You asks for the other list without waiting for this one', () async {
    final asked = <Mode>[];
    final anime = Completer<ListCollection>();
    final container = await testContainer(
      overrides: [
        listCollectionProvider.overrideWith((ref, mode) {
          asked.add(mode);
          // this list holds until released; the other answers at once
          return mode == Mode.anime ? anime.future : const ListCollection(entries: []);
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(forYouProvider(Mode.anime), (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    expect(asked.toSet(), {Mode.anime, Mode.manga});

    anime.complete(const ListCollection(entries: []));
    final forYou = await container.read(forYouProvider(Mode.anime).future);
    expect(forYou.coldStart, isTrue);
  });
}
