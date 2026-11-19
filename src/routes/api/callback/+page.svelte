<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { readPref } from '#lib/state/prefs.ts';
	import { session } from '#lib/state/session.svelte.ts';
	import { OAUTH_STATE_STORAGE_KEY, ONBOARDED_STORAGE_KEY } from '#lib/storage-keys.ts';

	/** The state the login page saved for this tab's sign-in, used up on read. */
	function takeSavedState(): string | null {
		try {
			const saved = sessionStorage.getItem(OAUTH_STATE_STORAGE_KEY);
			sessionStorage.removeItem(OAUTH_STATE_STORAGE_KEY);
			return saved;
		} catch {
			return null;
		}
	}

	let error = $state('');

	async function handleCallback() {
		// Read URL hash fragment (#access_token=...&token_type=Bearer&...)
		const rawHash = window.location.hash;
		const hash = rawHash.startsWith('#') ? rawHash.slice(1) : rawHash;

		if (!hash) {
			error = 'No authentication data received from AniList.';
			return;
		}

		const params = new URLSearchParams(hash);
		const accessToken = params.get('access_token');
		const errorParam = params.get('error');
		const savedState = takeSavedState();

		// Scrub credentials from browser history before anything else
		history.replaceState(null, '', window.location.pathname);

		if (errorParam) {
			error = params.get('error_description') || errorParam;
			return;
		}

		if (!accessToken) {
			error = 'Missing access token in callback response.';
			return;
		}

		// a token this tab didn't ask for (a link planting someone else's
		// account): never sign in with it
		if (!savedState || params.get('state') !== savedState) {
			error = 'This sign-in didn’t start here, or took too long. Please sign in again.';
			return;
		}

		// Persists the token and fetches the real AniList viewer profile.
		// Never throws — on failure it logs out and leaves authState as 'error'.
		await session.setToken(accessToken);

		if (session.authState !== 'in') {
			error = 'Could not verify your AniList account. Please try again.';
			return;
		}

		// first sign-in on this device: three quick settings first (design 9c)
		goto(readPref(ONBOARDED_STORAGE_KEY) ? '/' : '/welcome', { replace: true });
	}

	onMount(() => {
		handleCallback();
	});
</script>

<div class="flex min-h-screen items-center justify-center bg-canvas px-6 text-ink">
	{#if error}
		<div
			class="flex max-w-sm flex-col items-center gap-4 rounded-[2px] border border-line bg-[rgba(29,26,22,.8)] p-6 text-center"
		>
			<span class="material-symbols-rounded text-3xl text-rose-500">error</span>
			<div class="space-y-1">
				<h2 class="font-display text-lg font-medium tracking-[-0.01em]">Authentication Failed</h2>
				<p class="text-sm text-muted">{error}</p>
			</div>
			<a
				href="/login"
				class="mt-2 flex h-11 w-full items-center justify-center rounded-[2px] bg-anime font-semibold text-anime-ink transition hover:opacity-90"
			>
				Back to Sign In
			</a>
		</div>
	{:else}
		<div class="flex flex-col items-center gap-3 text-center">
			<div
				class="grid h-12 w-12 animate-pulse place-items-center rounded-[2px] bg-anime font-display text-2xl font-extrabold text-anime-ink"
			>
				見
			</div>
			<p class="text-sm font-medium text-muted">Authorizing with AniList...</p>
		</div>
	{/if}
</div>
