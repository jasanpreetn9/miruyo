import { externalUrl } from '#lib/anilist/adapt.ts';
import { stripHtml } from '#lib/anilist/humanize.ts';

// AniList's descriptions for characters and staff are its own markdown:
// __bold__, _italic_, [links](…), ~!spoilers!~, plus images, videos and
// centring. They're turned into plain segments here (never HTML), so a page
// renders them as text and nothing in a description can inject markup.

export interface Segment {
	text: string;
	bold?: boolean;
	italic?: boolean;
	/** A miruyo path (/character/12) or an http(s) URL. */
	href?: string;
	/** Opens in a new tab: a link to another site. */
	external?: boolean;
	/** Gives away the story: hidden until asked for. */
	spoiler?: boolean;
}

/** One paragraph; a single line break inside it stays a '\n' in the text. */
export type Paragraph = Segment[];

export interface Fact {
	label: string;
	value: string;
}

/**
 * AniList links to its own characters, staff and titles open in miruyo;
 * other http(s) links open in a new tab; anything else is plain text.
 */
function linkTarget(url: string): Pick<Segment, 'href' | 'external'> {
	const own = url.match(/^https?:\/\/anilist\.co\/(character|staff|anime|manga)\/(\d+)/);
	if (own)
		return { href: `/${own[1] === 'anime' || own[1] === 'manga' ? 'title' : own[1]}/${own[2]}` };
	const safe = externalUrl(url);
	return safe ? { href: safe, external: true } : {};
}

/** Links, bold and italic, in that order, so a link's text keeps its own markup. */
const INLINE =
	/\[([^\]]+)\]\(([^)\s]+)\)|__(.+?)__|\*\*(.+?)\*\*|(?<![\w*])_(?!_)(.+?)_(?!\w)|(?<![\w*])\*(?![*\s])(.+?)\*(?![\w*])/gs;

function inline(text: string, base: Omit<Segment, 'text'>): Segment[] {
	const out: Segment[] = [];
	let at = 0;
	for (const m of text.matchAll(INLINE)) {
		if (m.index > at) out.push({ ...base, text: text.slice(at, m.index) });
		const [, linkText, url, bold1, bold2, italic1, italic2] = m;
		if (linkText !== undefined) out.push(...inline(linkText, { ...base, ...linkTarget(url) }));
		else if (bold1 ?? bold2) out.push(...inline((bold1 ?? bold2)!, { ...base, bold: true }));
		else out.push(...inline((italic1 ?? italic2)!, { ...base, italic: true }));
		at = m.index + m[0].length;
	}
	if (at < text.length) out.push({ ...base, text: text.slice(at) });
	return out;
}

/** Joins neighbours that look the same, so a spoiler or a bold run is one piece. */
function merge(segments: Segment[]): Segment[] {
	const out: Segment[] = [];
	for (const s of segments) {
		const last = out.at(-1);
		if (
			last &&
			last.bold === s.bold &&
			last.italic === s.italic &&
			last.href === s.href &&
			last.spoiler === s.spoiler
		) {
			last.text += s.text;
		} else out.push({ ...s });
	}
	return out;
}

/** Drops what can't be shown as text (images, videos, centring) and any HTML. */
function clean(markdown: string): string {
	return stripHtml(
		markdown
			.replace(/\r\n?/g, '\n')
			.replace(/(?:img|webm|youtube)\d*%?\s*\([^)]*\)/gi, '')
			.replace(/~~~/g, '')
			.replace(/^#{1,6}\s+/gm, '')
	);
}

/**
 * The leading "__Height:__ 157 cm" lines AniList puts at the top of a
 * description, which its own pages show as facts. Lines with a spoiler stay
 * in the text, where they can be hidden.
 */
function leadingFacts(text: string): { facts: Fact[]; rest: string } {
	const facts: Fact[] = [];
	const lines = text.split('\n');
	let i = 0;
	for (; i < lines.length; i++) {
		const line = lines[i].trim();
		if (!line) continue;
		const m = line.match(/^(?:__|\*\*)([^_*]+?):?(?:__|\*\*):?\s*(.+)$/);
		if (!m || m[2].includes('~!')) break;
		const value = inline(m[2], {})
			.map((s) => s.text)
			.join('')
			.trim();
		if (!value) break;
		facts.push({ label: m[1].trim(), value });
	}
	return { facts, rest: lines.slice(i).join('\n') };
}

/** A character's or staff member's description, as facts and paragraphs. */
export function parseDescription(markdown: string | null | undefined): {
	facts: Fact[];
	paragraphs: Paragraph[];
} {
	if (!markdown) return { facts: [], paragraphs: [] };
	const { facts, rest } = leadingFacts(clean(markdown));

	// spoilers can run across paragraphs, so they're split out first
	const paragraphs: Segment[][] = [[]];
	let spoiler = false;
	for (const piece of rest.split(/(~!|!~)/)) {
		if (piece === '~!' || piece === '!~') {
			spoiler = piece === '~!';
			continue;
		}
		piece.split(/\n[ \t]*\n+/).forEach((chunk, i) => {
			if (i > 0) paragraphs.push([]);
			if (chunk) paragraphs.at(-1)!.push(...inline(chunk, spoiler ? { spoiler: true } : {}));
		});
	}
	return {
		facts,
		paragraphs: paragraphs
			.map((p) => {
				const merged = merge(p);
				// trim the paragraph's ends, not the text inside it
				if (merged[0]) merged[0].text = merged[0].text.trimStart();
				if (merged.at(-1)) merged.at(-1)!.text = merged.at(-1)!.text.trimEnd();
				return merged.filter((s) => s.text);
			})
			.filter((p) => p.length)
	};
}
