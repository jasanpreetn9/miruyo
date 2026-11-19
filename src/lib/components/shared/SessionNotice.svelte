<script lang="ts">
	import { busyCards } from '#lib/state/busy-notice.svelte.ts';
	import { session } from '#lib/state/session.svelte.ts';

	// rate limited, the page's own error cards already say so: one message, not two
	const quiet = $derived(session.rateLimited && busyCards.count > 0);
</script>

{#if session.signOutReason === 'expired'}
	<div
		class="flex items-center gap-3 border-t border-line bg-[rgba(245,184,61,.1)] px-4 py-2.5 text-sm lg:px-8"
		role="status"
	>
		<span class="material-symbols-rounded !text-[20px] text-gold" aria-hidden="true">key_off</span>
		<div class="flex-1 text-ink">
			AniList signed you out — your session expired or access was revoked. Log in again to keep
			syncing.
		</div>
		<a
			href="/login"
			class="touch-target relative flex h-8 press items-center rounded-[2px] bg-gold px-3 text-[13px] font-semibold text-[#241703] hover:text-[#241703]"
		>
			Log in
		</a>
		<button
			onclick={() => session.dismissSignOutReason()}
			aria-label="Dismiss"
			class="touch-target relative grid h-8 w-8 press place-items-center rounded-[2px] text-muted hover:text-ink"
		>
			<span class="material-symbols-rounded !text-[20px]">close</span>
		</button>
	</div>
{:else if session.authState === 'error' && !quiet}
	<div
		class="flex items-center gap-3 border-t border-line bg-[rgba(255,107,139,.08)] px-4 py-2.5 text-sm lg:px-8"
		role="alert"
	>
		<span class="material-symbols-rounded !text-[20px] text-[#FF8FA8]" aria-hidden="true"
			>cloud_off</span
		>
		<div class="flex-1 text-ink">
			{session.rateLimited
				? 'AniList is busy right now.'
				: 'Couldn’t reach AniList to check your account.'}
			{#if session.retry.active}
				We'll try again automatically in
				<span class="font-mono">{session.retry.label}</span>.
			{/if}
		</div>
		<button
			onclick={() => session.loadCurrentUser()}
			class="touch-target relative flex h-8 press items-center gap-1 btn-quiet px-3 text-[13px] font-semibold"
		>
			<span class="material-symbols-rounded !text-[18px]">refresh</span>
			Retry now
		</button>
	</div>
{/if}
