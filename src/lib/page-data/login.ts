/**
 * `state` ties the redirect back to a sign-in started in this tab: without it,
 * any page could send the browser to /api/callback with someone else's token
 * and sign the viewer in to that account.
 */
export function createAuthUrl(clientId: string, state?: string): string {
	const url = new URL('https://anilist.co/api/v2/oauth/authorize');
	url.searchParams.set('client_id', clientId);
	url.searchParams.set('response_type', 'token');
	if (state) url.searchParams.set('state', state);
	return url.toString();
}

/** A fresh, unguessable `state` for one sign-in. */
export function newAuthState(): string {
	const bytes = crypto.getRandomValues(new Uint8Array(16));
	return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}
