import { describe, expect, it } from 'vitest';
import { LOW_WATER, Pacer } from './pacer.ts';

/** A pacer on a fake clock: sleeping moves the clock, and records how long. */
function fakePacer() {
	let t = 1_000_000;
	const slept: number[] = [];
	const pacer = new Pacer(
		() => t,
		async (ms) => {
			slept.push(ms);
			t += ms;
		}
	);
	return { pacer, slept, advance: (ms: number) => (t += ms), now: () => t };
}

const headers = (limit: number, remaining: number) =>
	new Headers({ 'X-RateLimit-Limit': String(limit), 'X-RateLimit-Remaining': String(remaining) });

describe('Pacer', () => {
	it('sends at once while plenty are left, or before AniList has said', async () => {
		const { pacer, slept } = fakePacer();
		for (let i = 0; i < 20; i++) await pacer.slot();
		pacer.settle(headers(30, 25));
		await pacer.slot();
		expect(slept).toEqual([]);
	});

	it('spaces requests at the limit’s pace once few are left', async () => {
		const { pacer, slept } = fakePacer();
		await pacer.slot();
		pacer.settle(headers(30, LOW_WATER));
		await pacer.slot();
		await pacer.slot();
		await pacer.slot();
		// 30 a minute: one every two seconds
		expect(slept).toEqual([2000, 2000]);
	});

	it('counts what is in flight against what is left', async () => {
		const { pacer, slept } = fakePacer();
		await pacer.slot();
		pacer.settle(headers(90, LOW_WATER + 2));
		await pacer.slot(); // 7 left: goes
		await pacer.slot(); // 6 left: goes
		await pacer.slot(); // 5 left: goes, and spacing starts
		expect(slept).toEqual([]);
		await pacer.slot();
		expect(slept).toEqual([pacer.spacing]);
	});

	it('forgets a low count after a minute', async () => {
		const { pacer, slept, advance } = fakePacer();
		await pacer.slot();
		pacer.settle(headers(30, 1));
		advance(61_000);
		await pacer.slot();
		await pacer.slot();
		expect(slept).toEqual([]);
	});

	it('after a 429 with Retry-After, everything waits it out', async () => {
		const { pacer, slept } = fakePacer();
		pacer.pause(10);
		await pacer.slot();
		await pacer.slot();
		expect(slept).toEqual([10_000]);
	});

	it('a request with no response (a browser 429) leaves nothing, so the rest go one at a time', async () => {
		const { pacer, slept } = fakePacer();
		await pacer.slot();
		pacer.settle(null);
		pacer.limited();
		await pacer.slot();
		await pacer.slot();
		expect(slept).toEqual([pacer.spacing]);
	});

	it('callers waiting together go out one spacing apart', async () => {
		const { pacer, slept } = fakePacer();
		await pacer.slot();
		pacer.settle(headers(60, 0));
		await Promise.all([pacer.slot(), pacer.slot(), pacer.slot()]);
		// the first goes now; the others wait one and two seconds
		expect(slept.length).toBeGreaterThan(0);
		expect(Math.max(...slept)).toBeLessThanOrEqual(2000);
	});

	it('remembers the last count across page loads', async () => {
		const saved = new Map<string, string>();
		const storage = {
			getItem: (k: string) => saved.get(k) ?? null,
			setItem: (k: string, v: string) => void saved.set(k, v)
		};
		let t = 1_000_000;
		const slept: number[] = [];
		const make = () =>
			new Pacer(
				() => t,
				async (ms) => {
					slept.push(ms);
					t += ms;
				},
				{ storage, key: 'pace' }
			);
		const first = make();
		await first.slot();
		first.settle(headers(30, 1));
		// a reload: a new pacer starts from what the last one saw
		const second = make();
		expect(second.left).toBe(1);
		expect(second.spacing).toBe(2000);
		await second.slot();
		await second.slot();
		expect(slept).toEqual([2000]);
	});
});
