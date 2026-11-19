import { createSubscriber } from 'svelte/reactivity';

/**
 * The current time as a reactive value, for live countdowns. It only ticks
 * while something on screen is reading it.
 */
class Clock {
	#subscribe = createSubscriber((update) => {
		const timer = setInterval(update, 1000);
		return () => clearInterval(timer);
	});

	/** Unix seconds. */
	get seconds(): number {
		this.#subscribe();
		return Math.floor(Date.now() / 1000);
	}
}

export const clock = new Clock();
