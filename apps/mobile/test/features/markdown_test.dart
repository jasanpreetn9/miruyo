// Ported from apps/web/src/lib/page-data/markdown.test.ts.

import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/features/person/markdown.dart';

void main() {
  test('lifts the leading "__Label:__ value" lines into facts', () {
    final (:facts, :paragraphs) = parseDescription(
      '__Height:__ 157 cm\n__Affiliation:__ [Haikyo](https://haikyo.co.jp)\n\nShe is a voice actress.',
    );
    expect(facts, [(label: 'Height', value: '157 cm'), (label: 'Affiliation', value: 'Haikyo')]);
    expect(paragraphs, [
      [const Segment('She is a voice actress.')],
    ]);
  });

  test('keeps a fact with a spoiler in the text, where it can be hidden', () {
    final (:facts, :paragraphs) = parseDescription('__Age:__ 16\n__Status:__ ~!Deceased!~');
    expect(facts, [(label: 'Age', value: '16')]);
    expect(paragraphs[0], [
      const Segment('Status:', bold: true),
      const Segment(' '),
      const Segment('Deceased', spoiler: true),
    ]);
  });

  test('turns AniList links into miruyo links and keeps other sites external', () {
    final (facts: _, :paragraphs) = parseDescription(
      "Frieren is [Fern](https://anilist.co/character/183965)'s master, from [the anime](https://anilist.co/anime/154587/Sousou-no-Frieren). [Twitter](https://twitter.com/x) [bad](javascript:alert(1))",
    );
    expect(paragraphs[0], [
      const Segment('Frieren is '),
      const Segment('Fern', href: '/character/183965'),
      const Segment("'s master, from "),
      const Segment('the anime', href: '/title/154587'),
      const Segment('. '),
      const Segment('Twitter', href: 'https://twitter.com/x', external: true),
      const Segment(' bad)'),
    ]);
  });

  test('marks bold and italic, without touching underscores inside words', () {
    final (facts: _, :paragraphs) = parseDescription('The _Sousou no Frieren_ hero, **Himmel** of snake_case');
    expect(paragraphs[0], [
      const Segment('The '),
      const Segment('Sousou no Frieren', italic: true),
      const Segment(' hero, '),
      const Segment('Himmel', bold: true),
      const Segment(' of snake_case'),
    ]);
  });

  test('hides spoilers, even when one runs across paragraphs', () {
    final (facts: _, :paragraphs) = parseDescription('Before. ~!He dies.\n\nShe grieves.!~ After.');
    expect(paragraphs, [
      [const Segment('Before. '), const Segment('He dies.', spoiler: true)],
      [const Segment('She grieves.', spoiler: true), const Segment(' After.')],
    ]);
  });

  test('drops images, videos, centring and HTML, and decodes entities', () {
    final (facts: _, :paragraphs) = parseDescription(
      '~~~img220(https://x.com/a.png)~~~\n\n<b>Hi</b> &amp; youtube(abc) bye<br>next line',
    );
    expect(paragraphs, [
      [const Segment('Hi &  bye\nnext line')],
    ]);
  });

  test('is empty for no description', () {
    final d = parseDescription(null);
    expect(d.facts, isEmpty);
    expect(d.paragraphs, isEmpty);
  });
}
