import type { MediaListStatus, MediaSeason } from './types.ts';

const FORMAT_LABELS: Record<string, string> = {
	TV: 'TV',
	TV_SHORT: 'TV Short',
	MOVIE: 'Movie',
	SPECIAL: 'Special',
	OVA: 'OVA',
	ONA: 'ONA',
	MUSIC: 'Music',
	MANGA: 'Manga',
	NOVEL: 'Novel',
	ONE_SHOT: 'One-shot'
};

export function humanizeFormat(format: string | null): string {
	if (!format) return 'Unknown';
	return FORMAT_LABELS[format] ?? format;
}

const STATUS_LABELS: Record<string, string> = {
	FINISHED: 'Finished',
	RELEASING: 'Releasing',
	NOT_YET_RELEASED: 'Not yet released',
	CANCELLED: 'Cancelled',
	HIATUS: 'Hiatus'
};

export function humanizeStatus(status: string | null): string {
	if (!status) return 'Unknown';
	return STATUS_LABELS[status] ?? status;
}

export function humanizeSeason(season: MediaSeason): string {
	return season.charAt(0) + season.slice(1).toLowerCase();
}

const LIST_STATUSES = new Set<string>([
	'CURRENT',
	'PLANNING',
	'COMPLETED',
	'DROPPED',
	'PAUSED',
	'REPEATING'
]);

/** Narrows AniList's MediaListStatus string, falling back to CURRENT for
 *  anything unexpected. Display labels live in catalog/status.ts, since the
 *  verb depends on the mode (Watching / Reading). */
export function toListStatus(status: string): MediaListStatus {
	return LIST_STATUSES.has(status) ? (status as MediaListStatus) : 'CURRENT';
}

/** Mirrors the mock dataset's compact countdown style ("2d 4h", "19h 12m"). */
export function formatTimeUntil(totalSeconds: number): string {
	if (totalSeconds <= 0) return 'now';
	const days = Math.floor(totalSeconds / 86400);
	const hours = Math.floor((totalSeconds % 86400) / 3600);
	const minutes = Math.floor((totalSeconds % 3600) / 60);

	if (days > 0) return hours > 0 ? `${days}d ${hours}h` : `${days}d`;
	if (hours > 0) return `${hours}h ${String(minutes).padStart(2, '0')}m`;
	return `${minutes}m`;
}

const NAMED_ENTITIES: Record<string, string> = {
	amp: '&',
	lt: '<',
	gt: '>',
	quot: '"',
	apos: "'",
	nbsp: ' ',
	mdash: '—',
	ndash: '–',
	hellip: '…',
	rsquo: '’',
	lsquo: '‘',
	rdquo: '”',
	ldquo: '“'
};

/** AniList descriptions contain tags (<br>, <i>) and HTML entities even with
 *  asHtml: false — drop the tags (keeping line breaks as whitespace so words
 *  don't run together) and decode the entities. */
export function stripHtml(html: string): string {
	return html
		.replace(/<br\s*\/?>/gi, '\n')
		.replace(/<[^>]*>/g, '')
		.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (match, code: string) => {
			if (code[0] === '#') {
				const n =
					code[1] === 'x' || code[1] === 'X' ? parseInt(code.slice(2), 16) : Number(code.slice(1));
				// out-of-range code points (&#99999999;) would throw a RangeError
				return Number.isInteger(n) && n >= 0 && n <= 0x10ffff ? String.fromCodePoint(n) : match;
			}
			return NAMED_ENTITIES[code.toLowerCase()] ?? match;
		})
		.trim();
}
