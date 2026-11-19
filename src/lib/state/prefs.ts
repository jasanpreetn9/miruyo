import { browser } from '$app/env';

// localStorage can throw (private windows, blocked site data), and these are
// only conveniences — so every read and write fails soft.

export function readPref(key: string): string | null {
	if (!browser) return null;
	try {
		return localStorage.getItem(key);
	} catch {
		return null;
	}
}

export function writePref(key: string, value: string): void {
	if (!browser) return;
	try {
		localStorage.setItem(key, value);
	} catch {
		// not persisted; the app still works for this visit
	}
}

/** A set of strings stored as a JSON array. */
export function readPrefSet(key: string): Set<string> {
	try {
		const parsed: unknown = JSON.parse(readPref(key) ?? '[]');
		return new Set(Array.isArray(parsed) ? parsed.map(String) : []);
	} catch {
		return new Set();
	}
}

export function addToPrefSet(key: string, value: string): void {
	const set = readPrefSet(key);
	set.add(value);
	writePref(key, JSON.stringify([...set]));
}
