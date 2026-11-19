import { describe, expect, it } from 'vitest';
import { isUntracked, withoutCloudflareAnalytics } from './untracked.ts';

describe('isUntracked', () => {
	it('is the sign-in callback, and only it', () => {
		expect(isUntracked('/api/callback')).toBe(true);
		expect(isUntracked('/api/callback/')).toBe(true);
		expect(isUntracked('/')).toBe(false);
		expect(isUntracked('/api/callbacks')).toBe(false);
		expect(isUntracked('/title/1')).toBe(false);
	});
});

describe('withoutCloudflareAnalytics', () => {
	it("takes Cloudflare's beacon and report hosts out, leaving the rest as it was", () => {
		const csp =
			"default-src 'self'; connect-src 'self' https://graphql.anilist.co https://cloudflareinsights.com; " +
			"script-src 'self' https://static.cloudflareinsights.com 'unsafe-hashes' 'sha256-abc='; " +
			"frame-ancestors 'none'";
		expect(withoutCloudflareAnalytics(csp)).toBe(
			"default-src 'self'; connect-src 'self' https://graphql.anilist.co; " +
				"script-src 'self' 'unsafe-hashes' 'sha256-abc='; frame-ancestors 'none'"
		);
	});

	it('leaves a policy without them alone', () => {
		const csp = "default-src 'self'; script-src 'self'";
		expect(withoutCloudflareAnalytics(csp)).toBe(csp);
	});
});
