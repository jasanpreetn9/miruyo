<script lang="ts">
	import { untrack } from 'svelte';
	import { busyCards } from '#lib/state/busy-notice.svelte.ts';

	interface Props {
		onRetry?: () => void;
		detail?: string;
		/** Set while an automatic retry is pending: the "0:12" until it runs. */
		retryIn?: string;
		/** The failure was AniList's rate limit, rather than no response. */
		rateLimited?: boolean;
		/** Headline when AniList didn't respond (the rate-limit headline is fixed). */
		title?: string;
	}

	let {
		onRetry,
		detail,
		retryIn,
		rateLimited = true,
		title = "Couldn't load your feed"
	}: Props = $props();

	// saying AniList is busy, it stands in for the session banner's same message
	const busy = $derived(!!retryIn && rateLimited);
	$effect(() => {
		if (!busy) return;
		// untracked: reading the count it changes would re-run this forever
		untrack(() => busyCards.count++);
		return () => untrack(() => busyCards.count--);
	});
</script>

<div
	class="flex flex-col items-start gap-3 border-y border-line py-5"
	style="box-shadow:inset 2px 0 0 #ff8fa8;padding-left:18px"
	role="alert"
>
	<div
		class="grid h-10 w-10 place-items-center rounded-full"
		style="background:rgba(255,107,139,.14);color:#FF8FA8"
	>
		<span class="material-symbols-rounded !text-[22px]">cloud_off</span>
	</div>
	{#if retryIn && rateLimited}
		<div class="text-base font-semibold">AniList is busy right now</div>
		<div class="text-sm leading-relaxed text-muted">
			We hit their rate limit. Your list is safe — we'll try again automatically in
			<span class="font-mono text-ink" data-testid="retry-countdown">{retryIn}</span>.
		</div>
	{:else}
		<div class="text-base font-semibold">{title}</div>
		<div class="text-sm leading-relaxed text-muted">
			Something went wrong talking to AniList. Your list is safe —
			{#if retryIn}
				we'll try again automatically in
				<span class="font-mono text-ink" data-testid="retry-countdown">{retryIn}</span>.
			{:else}
				try again.
			{/if}
		</div>
		{#if detail}
			<div class="border-l border-line pl-2.5 font-mono text-xs text-dim">{detail}</div>
		{/if}
	{/if}
	<button
		onclick={onRetry}
		class="flex h-11 press items-center gap-1.5 btn-quiet px-4 text-sm font-semibold"
	>
		<span class="material-symbols-rounded !text-[20px]">refresh</span>
		Retry now
	</button>
</div>
