/** "0:12", "1:05" — the design's rate-limit countdown format. */
export function formatCountdown(seconds: number): string {
	const s = Math.max(0, Math.ceil(seconds));
	return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

/** Counts down once a second, then calls `onDone` — for automatic retries. */
export class RetryCountdown {
	remaining = $state(0);
	#timer: ReturnType<typeof setInterval> | undefined;

	get active(): boolean {
		return this.remaining > 0;
	}

	get label(): string {
		return formatCountdown(this.remaining);
	}

	start(seconds: number, onDone: () => void): void {
		this.stop();
		this.remaining = Math.max(1, Math.ceil(seconds));
		this.#timer = setInterval(() => {
			this.remaining -= 1;
			if (this.remaining <= 0) {
				this.stop();
				onDone();
			}
		}, 1000);
	}

	stop(): void {
		clearInterval(this.#timer);
		this.#timer = undefined;
		this.remaining = 0;
	}
}
