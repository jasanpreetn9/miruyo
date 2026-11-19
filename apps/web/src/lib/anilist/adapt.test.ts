import { describe, expect, it } from 'vitest';
import { adaptMedia, anilistUrl, coverColor } from './adapt.ts';
import { makeEntry, makeManga, makeMedia } from './fixtures.ts';

describe('adaptMedia', () => {
	it('maps core anime fields', () => {
		const t = adaptMedia(makeMedia({ averageScore: 87 }));
		expect(t).toMatchObject({
			id: 1,
			title: 'Romaji Title',
			en: 'English Title',
			type: 'ANIME',
			format: 'TV',
			eps: 24,
			score: 8.7,
			studio: 'Studio One',
			season: 'Fall 2026',
			status: 'Releasing',
			synopsis: 'A synopsis.',
			unit: 'EP'
		});
		expect(t.me).toBeUndefined();
	});

	it("shows the viewer's preferred title by default", () => {
		const t = adaptMedia(
			makeMedia({
				title: { romaji: 'Romaji', english: 'Eng', native: '日本語', userPreferred: 'Pref' }
			})
		);
		expect(t.title).toBe('Pref');
		expect(t.en).toBe('Eng');
	});

	it('shows the English title when asked (signed-out visitors)', () => {
		const media = makeMedia({
			title: { romaji: 'Romaji', english: 'Eng', native: null, userPreferred: 'Pref' }
		});
		expect(adaptMedia(media, undefined, { titles: 'english' }).title).toBe('Eng');
	});

	it('falls back through title variants', () => {
		const noEnglish = { romaji: 'Romaji', english: null, native: null, userPreferred: 'Pref' };
		expect(
			adaptMedia(makeMedia({ title: noEnglish }), undefined, { titles: 'english' }).title
		).toBe('Romaji');
		const noPreferred = { romaji: null, english: 'Eng', native: null, userPreferred: null };
		expect(adaptMedia(makeMedia({ title: noPreferred })).title).toBe('Eng');
		const untitled = adaptMedia(
			makeMedia({ title: { romaji: null, english: null, native: null, userPreferred: null } })
		);
		expect(untitled.title).toBe('Untitled');
	});

	it('handles missing score, colour and season', () => {
		const t = adaptMedia(
			makeMedia({
				averageScore: null,
				season: null,
				coverImage: { extraLarge: null, large: null, medium: null, color: null }
			})
		);
		expect(t.score).toBe(0);
		expect(t.color).toBe('#30363d');
		expect(t.season).toBeUndefined();
	});

	it('maps manga chapters and leaves episodes unset', () => {
		const t = adaptMedia(makeManga());
		expect(t.eps).toBeUndefined();
		expect(t.ch).toBe(120);
		expect(t.unit).toBe('CH');
		expect(t.studio).toBeUndefined();
	});

	it('maps the next airing episode to a countdown', () => {
		const t = adaptMedia(
			makeMedia({ nextAiringEpisode: { episode: 9, airingAt: 0, timeUntilAiring: 2 * 86400 } })
		);
		expect(t.next).toEqual({ ep: 9, in: '2d', at: 0 });
	});

	it('maps the viewer list entry', () => {
		const media = makeMedia();
		const t = adaptMedia(media, makeEntry(media, { status: 'PAUSED', progress: 3 }));
		expect(t.me).toMatchObject({ s: 'PAUSED', p: 3, of: '24' });
	});

	it('strips HTML from the description', () => {
		expect(adaptMedia(makeMedia({ description: 'A &amp; B<br>C' })).synopsis).toBe('A & B\nC');
	});

	it('uses the real cover image, preferring extraLarge', () => {
		const t = adaptMedia(
			makeMedia({
				coverImage: {
					extraLarge: 'https://x/xl.jpg',
					large: 'https://x/l.jpg',
					medium: null,
					color: null
				}
			})
		);
		expect(t.cover).toBe("center / cover no-repeat url('https://x/xl.jpg')");
		expect(t.coverMissing).toBeUndefined();
	});

	it('offers the 100px cover beside the thumbnail, when the query asked for it', () => {
		const cover = { extraLarge: 'https://x/xl.jpg', large: 'https://x/l.jpg', color: null };
		expect(
			adaptMedia(makeMedia({ coverImage: { ...cover, medium: 'https://x/m.jpg' } }))
		).toMatchObject({
			thumbUrl: 'https://x/l.jpg',
			thumbSmallUrl: 'https://x/m.jpg'
		});
		expect(
			adaptMedia(makeMedia({ coverImage: { ...cover, medium: null } })).thumbSmallUrl
		).toBeUndefined();
	});

	it('escapes characters that could break out of the CSS url()', () => {
		const t = adaptMedia(
			makeMedia({
				coverImage: { extraLarge: "https://x/a'b(c).jpg", large: null, medium: null, color: null }
			})
		);
		expect(t.cover).toBe("center / cover no-repeat url('https://x/a%27b%28c%29.jpg')");
	});

	it('keeps the generated gradient cover when there is no image', () => {
		const t = adaptMedia(makeMedia());
		expect(t.cover).toContain('linear-gradient');
		expect(t.coverMissing).toBe(true);
	});

	it('uses the list entry a feed query attaches when none is passed', () => {
		const t = adaptMedia(makeMedia({ mediaListEntry: { id: 4, status: 'PAUSED', progress: 2 } }));
		expect(t.me).toMatchObject({ s: 'PAUSED', p: 2 });
		expect(adaptMedia(makeMedia({ mediaListEntry: null })).me).toBeUndefined();
	});

	it('turns the banner image into a safe CSS background', () => {
		expect(adaptMedia(makeMedia({ bannerImage: "https://x/b'(1).jpg" })).banner).toBe(
			"center / cover no-repeat url('https://x/b%27%281%29.jpg')"
		);
		expect(adaptMedia(makeMedia()).banner).toBeUndefined();
	});
});

describe('coverColor', () => {
	it('keeps hex colours and replaces anything that could inject CSS', () => {
		expect(coverColor('#e4a15d')).toBe('#e4a15d');
		expect(coverColor(null)).toBe('#30363d');
		expect(coverColor('red;background:url(https://evil/x)')).toBe('#30363d');
	});
});

describe('anilistUrl', () => {
	it('keeps https anilist.co links and falls back for anything else', () => {
		expect(anilistUrl('https://anilist.co/user/a', 'f')).toBe('https://anilist.co/user/a');
		expect(anilistUrl('javascript:alert(1)', 'f')).toBe('f');
		expect(anilistUrl('https://anilist.co.evil.example/x', 'f')).toBe('f');
		expect(anilistUrl('not a url')).toBeNull();
		expect(anilistUrl(null)).toBeNull();
	});
});
