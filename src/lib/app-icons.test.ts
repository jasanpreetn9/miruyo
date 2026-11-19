import { describe, expect, it } from 'vitest';
import layout from '../routes/+layout.svelte?raw';
import manifestText from '../../static/manifest.webmanifest?raw';

// The icons the root layout and the web manifest point at: home screens,
// link previews, crawlers and tabs. Each must be in static/ at the size it
// claims, or that surface quietly falls back to a blank or generic icon.

const files = import.meta.glob<string>('/static/*.{png,ico}', {
	query: '?inline',
	import: 'default',
	eager: true
});

/** A static file's bytes (Vite inlines it as a data: URL). */
function read(path: string): DataView {
	const url = files[`/static${path}`];
	if (!url) throw new Error(`static${path} is missing`);
	const bytes = Uint8Array.from(atob(url.split(',')[1]), (c) => c.charCodeAt(0));
	return new DataView(bytes.buffer);
}

/** A PNG's width and height, from its IHDR chunk. */
function pngSize(png: DataView): [number, number] {
	expect(png.getUint32(0)).toBe(0x89504e47); // \x89PNG
	return [png.getUint32(16), png.getUint32(20)];
}

describe('app icons', () => {
	it('links a favicon.ico, the SVG, an apple-touch-icon and the manifest', () => {
		for (const tag of [
			'rel="icon" href="/favicon.ico"',
			'rel="apple-touch-icon" href="/apple-touch-icon.png"',
			'rel="manifest" href="/manifest.webmanifest"'
		]) {
			expect(layout).toContain(tag);
		}
		expect(layout).toMatch(/rel="icon" href=\{favicon\} type="image\/svg\+xml"/);
	});

	it('has a 180px apple-touch-icon', () => {
		expect(pngSize(read('/apple-touch-icon.png'))).toEqual([180, 180]);
	});

	it('has a favicon.ico holding 16, 32 and 48px images', () => {
		const ico = read('/favicon.ico');
		expect(ico.getUint16(2, true)).toBe(1); // an icon, not a cursor
		const count = ico.getUint16(4, true);
		const sizes = Array.from({ length: count }, (_, i) => ico.getUint8(6 + i * 16));
		expect(sizes).toEqual([16, 32, 48]);
	});

	it('lists manifest icons that exist at their stated sizes, one maskable', () => {
		const manifest = JSON.parse(manifestText) as {
			name: string;
			start_url: string;
			icons: { src: string; sizes: string; type: string; purpose: string }[];
		};
		expect(manifest).toMatchObject({ name: 'miruyo', start_url: '/' });
		for (const icon of manifest.icons) {
			const [w, h] = icon.sizes.split('x').map(Number);
			expect(pngSize(read(icon.src)), icon.src).toEqual([w, h]);
		}
		expect(manifest.icons.map((i) => i.sizes)).toEqual(
			expect.arrayContaining(['192x192', '512x512'])
		);
		expect(manifest.icons.some((i) => i.purpose === 'maskable')).toBe(true);
	});
});
