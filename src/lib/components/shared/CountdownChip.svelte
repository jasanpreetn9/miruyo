<script lang="ts">
	import { airingChip } from '#lib/catalog/airing.ts';
	import type { NextAiring } from '#lib/catalog/types.ts';
	import { clock } from '#lib/state/clock.svelte.ts';

	interface Props {
		next: NextAiring;
	}

	let { next }: Props = $props();

	// blue at rest; the accent with a live dot inside 24h; "Airing now" just after release
	const chip = $derived(airingChip(next, clock.seconds));
	const hot = $derived(chip?.phase === 'soon' || chip?.phase === 'live');
</script>

{#if chip}
	<div
		class="flex h-6 w-fit items-center gap-1 font-mono text-[11px] {hot ? 'font-semibold' : ''}"
		style="color:{hot ? 'var(--color-anime-soft)' : 'var(--color-muted)'}"
		data-phase={chip.phase}
	>
		{#if hot}
			<span class="mx-[3px] h-1.5 w-1.5 rounded-full bg-anime" aria-hidden="true"></span>
		{:else}
			<span class="material-symbols-rounded !text-[14px]" aria-hidden="true">schedule</span>
		{/if}
		{chip.label}
	</div>
{/if}
