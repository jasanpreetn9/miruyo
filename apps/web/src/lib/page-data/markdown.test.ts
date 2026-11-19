import { describe, expect, it } from 'vitest';
import { parseDescription } from './markdown.ts';

describe('parseDescription', () => {
	it('lifts the leading "__Label:__ value" lines into facts', () => {
		const { facts, paragraphs } = parseDescription(
			'__Height:__ 157 cm\n__Affiliation:__ [Haikyo](https://haikyo.co.jp)\n\nShe is a voice actress.'
		);
		expect(facts).toEqual([
			{ label: 'Height', value: '157 cm' },
			{ label: 'Affiliation', value: 'Haikyo' }
		]);
		expect(paragraphs).toEqual([[{ text: 'She is a voice actress.' }]]);
	});

	it('keeps a fact with a spoiler in the text, where it can be hidden', () => {
		const { facts, paragraphs } = parseDescription('__Age:__ 16\n__Status:__ ~!Deceased!~');
		expect(facts).toEqual([{ label: 'Age', value: '16' }]);
		expect(paragraphs[0]).toEqual([
			{ text: 'Status:', bold: true },
			{ text: ' ' },
			{ text: 'Deceased', spoiler: true }
		]);
	});

	it('turns AniList links into miruyo links and keeps other sites external', () => {
		const { paragraphs } = parseDescription(
			"Frieren is [Fern](https://anilist.co/character/183965)'s master, from [the anime](https://anilist.co/anime/154587/Sousou-no-Frieren). [Twitter](https://twitter.com/x) [bad](javascript:alert(1))"
		);
		expect(paragraphs[0]).toEqual([
			{ text: 'Frieren is ' },
			{ text: 'Fern', href: '/character/183965' },
			{ text: "'s master, from " },
			{ text: 'the anime', href: '/title/154587' },
			{ text: '. ' },
			{ text: 'Twitter', href: 'https://twitter.com/x', external: true },
			{ text: ' bad)' }
		]);
	});

	it('marks bold and italic, without touching underscores inside words', () => {
		const { paragraphs } = parseDescription(
			'The _Sousou no Frieren_ hero, **Himmel** of snake_case'
		);
		expect(paragraphs[0]).toEqual([
			{ text: 'The ' },
			{ text: 'Sousou no Frieren', italic: true },
			{ text: ' hero, ' },
			{ text: 'Himmel', bold: true },
			{ text: ' of snake_case' }
		]);
	});

	it('hides spoilers, even when one runs across paragraphs', () => {
		const { paragraphs } = parseDescription('Before. ~!He dies.\n\nShe grieves.!~ After.');
		expect(paragraphs).toEqual([
			[{ text: 'Before. ' }, { text: 'He dies.', spoiler: true }],
			[{ text: 'She grieves.', spoiler: true }, { text: ' After.' }]
		]);
	});

	it('drops images, videos, centring and HTML, and decodes entities', () => {
		const { paragraphs } = parseDescription(
			'~~~img220(https://x.com/a.png)~~~\n\n<b>Hi</b> &amp; youtube(abc) bye<br>next line'
		);
		expect(paragraphs).toEqual([[{ text: 'Hi &  bye\nnext line' }]]);
	});

	it('is empty for no description', () => {
		expect(parseDescription(null)).toEqual({ facts: [], paragraphs: [] });
	});
});
