import { describe, expect, it } from 'vitest';
import { createAuthUrl, newAuthState } from './login.ts';

describe('createAuthUrl', () => {
	it('asks for an implicit grant, carrying the state when given', () => {
		const url = new URL(createAuthUrl('123', 'abc'));
		expect(url.origin + url.pathname).toBe('https://anilist.co/api/v2/oauth/authorize');
		expect(url.searchParams.get('client_id')).toBe('123');
		expect(url.searchParams.get('response_type')).toBe('token');
		expect(url.searchParams.get('state')).toBe('abc');
		expect(new URL(createAuthUrl('123')).searchParams.has('state')).toBe(false);
	});
});

describe('newAuthState', () => {
	it('is 128 random bits, new each time', () => {
		expect(newAuthState()).toMatch(/^[0-9a-f]{32}$/);
		expect(newAuthState()).not.toBe(newAuthState());
	});
});
