import type { Title } from './types.ts';

export type RawTitle = Omit<
	Title,
	| 'accent'
	| 'cover'
	| 'placeholder'
	| 'glow'
	| 'tint'
	| 'isAnime'
	| 'unit'
	| 'total'
	| 'countLabel'
	| 'short'
	| 'coverMissing'
>;

function hexLum(hex: string): number {
	const h = hex.replace('#', '');
	const v = [0, 2, 4].map((i) => {
		const c = parseInt(h.substr(i, 2), 16) / 255;
		return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
	});
	return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
}

export function dressTitle(title: RawTitle): Title {
	const color = title.color;
	const lum = hexLum(color);
	const accent =
		lum < 0.12
			? `color-mix(in oklch, ${color} 45%, #ffffff)`
			: lum > 0.6
				? `color-mix(in oklch, ${color} 80%, #000)`
				: color;
	const cover = `linear-gradient(160deg, color-mix(in oklch, ${color} 72%, #fff) 0%, ${color} 42%, color-mix(in oklch, ${color} 45%, #13110f) 100%)`;
	const glow = `0 18px 40px -14px color-mix(in oklch, ${accent} 70%, transparent)`;
	const tint = `color-mix(in oklch, ${accent} 16%, transparent)`;
	const isAnime = title.type === 'ANIME';
	const unit = isAnime ? 'EP' : 'CH';
	const total = isAnime ? (title.eps ?? null) : (title.ch ?? null);
	const countLabel = isAnime
		? title.eps
			? title.eps + ' eps'
			: '? eps'
		: title.ch
			? title.ch + ' ch'
			: 'Ongoing';

	const dressed: Title = {
		...title,
		// copy so the pct/of fields added below don't leak into the caller's object
		me: title.me ? { ...title.me } : undefined,
		accent,
		cover,
		placeholder: cover,
		glow,
		tint,
		isAnime,
		unit,
		total,
		countLabel,
		short: title.title.length > 34 ? title.title.slice(0, 32) + '…' : title.title
	};

	if (dressed.me) {
		const completeTotal = dressed.total || Math.max(dressed.me.p + 12, 24);
		dressed.me.pct = Math.round((dressed.me.p / completeTotal) * 100) + '%';
		dressed.me.of = dressed.total ? String(dressed.total) : '?';
	}

	return dressed;
}
