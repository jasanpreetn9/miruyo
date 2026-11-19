import { afterEach, describe, expect, it, vi } from 'vitest';
import { formatCountdown, RetryCountdown } from './countdown.svelte.ts';

afterEach(() => {
	vi.useRealTimers();
});

describe('formatCountdown', () => {
	it('formats as m:ss', () => {
		expect(formatCountdown(12)).toBe('0:12');
		expect(formatCountdown(65)).toBe('1:05');
		expect(formatCountdown(-3)).toBe('0:00');
	});
});

describe('RetryCountdown', () => {
	it('ticks down and fires once at zero', () => {
		vi.useFakeTimers();
		const done = vi.fn();
		const countdown = new RetryCountdown();
		countdown.start(3, done);
		expect(countdown.label).toBe('0:03');
		vi.advanceTimersByTime(2000);
		expect(countdown.remaining).toBe(1);
		expect(done).not.toHaveBeenCalled();
		vi.advanceTimersByTime(1000);
		expect(done).toHaveBeenCalledOnce();
		expect(countdown.active).toBe(false);
	});

	it('can be stopped early', () => {
		vi.useFakeTimers();
		const done = vi.fn();
		const countdown = new RetryCountdown();
		countdown.start(2, done);
		countdown.stop();
		vi.advanceTimersByTime(5000);
		expect(done).not.toHaveBeenCalled();
	});
});
