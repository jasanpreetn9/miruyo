import { describe, expect, it } from 'vitest';
import appHtml from '../app.html?raw';

// app.html loads only the Material Symbols the app uses (icon_names). An icon
// missing from that list renders as its name ("play_arrow"), so this checks
// every icon in the source is on it.

// every source file's text, keyed by path
const sources = import.meta.glob<string>(['/src/**/*.{svelte,ts}', '!/src/**/*.test.ts'], {
	query: '?raw',
	import: 'default',
	eager: true
});

/** Each icon span's content, by source file. */
function iconSpans(): [path: string, content: string][] {
	const spans: [string, string][] = [];
	for (const [path, source] of Object.entries(sources)) {
		for (const m of source.matchAll(/material-symbols-rounded/g)) {
			// the span's content, past its opening tag (skipping '=>' in attributes)
			let open = source.indexOf('>', m.index);
			while (source[open - 1] === '=') open = source.indexOf('>', open + 1);
			spans.push([path, source.slice(open + 1, source.indexOf('</', open)).trim()]);
		}
	}
	return spans;
}

/** Icon names a source passes as data: { icon: 'movie' }, icon: x ? 'a' : 'b'. */
function dataIcons(source: string): string[] {
	const names = [...source.matchAll(/\bicon\s*[:=]\s*'([a-z0-9_]+)'/g)].map((m) => m[1]);
	for (const m of source.matchAll(/\bicon:\s*\w+\s*\?\s*'([a-z0-9_]+)'\s*:\s*'([a-z0-9_]+)'/g)) {
		names.push(m[1], m[2]);
	}
	return names;
}

/** Icon names used in the source: icon spans' text, and the strings fed to them. */
function usedIcons(): Set<string> {
	const used = new Set<string>();
	for (const [, content] of iconSpans()) {
		if (!content.includes('{')) {
			if (content) used.add(content);
		} else {
			// literals in an expression: {open ? 'expand_less' : 'expand_more'}
			for (const lit of content.matchAll(/'([a-z0-9_]+)'/g)) used.add(lit[1]);
		}
	}
	for (const source of Object.values(sources)) for (const name of dataIcons(source)) used.add(name);
	return used;
}

// Icon spans named only by a variable, whose names the scan can't read in the
// same file — each checked by hand and covered by `indirect` below.
const REVIEWED: Record<string, string> = {
	'/src/lib/components/profile/StatsPanel.svelte': "stat cards: icon: '…' in page-data/stats.ts",
	'/src/routes/title/[id]/+page.svelte': 'score stars: star, star_half, star_border',
	'/src/routes/settings/+page.svelte': 'externalRow(…): settings, key_off'
};

function loadedIcons(): string[] {
	const names = appHtml.match(/icon_names=([a-z0-9_,]+)/)?.[1];
	if (!names) throw new Error('app.html has no icon_names list');
	return names.split(',');
}

describe('the icon font', () => {
	it('loads every icon the app uses', () => {
		const loaded = new Set(loadedIcons());
		// built at runtime, so the scan can't see them
		const indirect = ['star_half', 'star_border', 'settings', 'key_off'];
		const missing = [...usedIcons(), ...indirect].filter((name) => !loaded.has(name));
		expect(missing).toEqual([]);
	});

	it('can read the names of icons that come from a variable', () => {
		// e.g. a tab list of ['home', 'Home', 'home'] tuples rendered as {tab.icon}:
		// the scan can't see those names, so such icons must be passed as { icon: '…' }
		const unread = iconSpans()
			.filter(([, content]) => content.includes('{') && !/'[a-z0-9_]+'/.test(content))
			.filter(([path]) => !dataIcons(sources[path]).length && !(path in REVIEWED))
			.map(([path, content]) => `${path}: ${content}`);
		expect(unread).toEqual([]);
	});

	it('keeps icon_names alphabetical, as Google Fonts requires', () => {
		const names = loadedIcons();
		expect(names).toEqual([...names].sort());
	});
});
