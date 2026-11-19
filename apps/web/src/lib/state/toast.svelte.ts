export interface ToastAction {
	label: string;
	run: () => void;
}

export interface Toast {
	message: string;
	action?: ToastAction;
	/** 'error' reads in the error colour and stays a little longer. */
	tone?: 'info' | 'error';
}

/** How long a toast stays, in ms: long enough to reach Undo. */
const DURATION = 6000;

/** One toast at a time, app-wide; a new one replaces the current. Rendered by the root layout. */
class ToastState {
	current = $state<(Toast & { id: number }) | null>(null);
	#timer: ReturnType<typeof setTimeout> | undefined;
	#id = 0;

	show(toast: Toast): void {
		clearTimeout(this.#timer);
		const id = ++this.#id;
		this.current = { ...toast, id };
		this.#timer = setTimeout(
			() => this.dismiss(id),
			toast.tone === 'error' ? DURATION * 1.5 : DURATION
		);
	}

	/** Dismisses the toast `id` (or whatever is showing). */
	dismiss(id?: number): void {
		if (id !== undefined && this.current?.id !== id) return;
		clearTimeout(this.#timer);
		this.current = null;
	}
}

export const toast = new ToastState();
