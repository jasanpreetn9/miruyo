import { prefersReducedMotion } from 'svelte/motion';
import { fade, fly, type FlyParams, type TransitionConfig } from 'svelte/transition';

/** CSS cubic-bezier(x1, y1, x2, y2) as an easing function for Svelte transitions. */
export function cubicBezier(x1: number, y1: number, x2: number, y2: number): (t: number) => number {
	const cx = 3 * x1;
	const bx = 3 * (x2 - x1) - cx;
	const ax = 1 - cx - bx;
	const cy = 3 * y1;
	const by = 3 * (y2 - y1) - cy;
	const ay = 1 - cy - by;
	const sampleX = (t: number) => ((ax * t + bx) * t + cx) * t;
	const sampleY = (t: number) => ((ay * t + by) * t + cy) * t;
	const slopeX = (t: number) => (3 * ax * t + 2 * bx) * t + cx;

	return (x) => {
		if (x <= 0) return 0;
		if (x >= 1) return 1;
		// Newton–Raphson for the t where sampleX(t) = x, bisection as a fallback
		let t = x;
		for (let i = 0; i < 8; i++) {
			const err = sampleX(t) - x;
			if (Math.abs(err) < 1e-6) return sampleY(t);
			const d = slopeX(t);
			if (Math.abs(d) < 1e-6) break;
			t -= err / d;
		}
		let lo = 0;
		let hi = 1;
		t = x;
		while (hi - lo > 1e-6) {
			if (sampleX(t) < x) lo = t;
			else hi = t;
			t = (lo + hi) / 2;
		}
		return sampleY(t);
	};
}

/** Same tokens as layout.css (--ease-enter / --ease-exit / --duration-*). */
export const easeEnter = cubicBezier(0.2, 0.8, 0.2, 1);
export const easeExit = cubicBezier(0.4, 0, 1, 1);

export const DURATION = {
	press: 90,
	overlay: 160,
	lift: 180,
	panel: 240,
	sheet: 320
} as const;

/**
 * A slide that uses the enter easing coming in and the exit easing going out,
 * and becomes a plain fade under prefers-reduced-motion.
 */
export function slide(
	node: Element,
	params: FlyParams = {},
	options?: { direction?: 'in' | 'out' | 'both' }
): TransitionConfig {
	const duration = params.duration ?? DURATION.overlay;
	if (prefersReducedMotion.current) {
		return fade(node, { delay: params.delay, duration });
	}
	return fly(node, {
		...params,
		duration,
		easing: options?.direction === 'out' ? easeExit : easeEnter
	});
}

/**
 * Marks an element once it scrolls into view (`data-shown`), for CSS that
 * animates it then — a section's hairline drawing out (`.draw`). Use as
 * `{@attach reveal}`. Under reduced motion it's marked at once.
 */
export function reveal(node: Element) {
	if (prefersReducedMotion.current || typeof IntersectionObserver === 'undefined') {
		node.setAttribute('data-shown', '');
		return;
	}
	const io = new IntersectionObserver(
		([entry]) => {
			if (!entry.isIntersecting) return;
			node.setAttribute('data-shown', '');
			io.disconnect();
		},
		{ rootMargin: '0px 0px -6% 0px' }
	);
	io.observe(node);
	return () => io.disconnect();
}
