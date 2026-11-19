<script lang="ts">
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import type { MediaListStatus } from '#lib/anilist/types.ts';
	import StatusMenu from '#lib/components/shared/StatusMenu.svelte';
	import type { SeasonCard } from '#lib/page-data/season-chart.ts';
	import { editor } from '#lib/state/editor.svelte.ts';
	import { changeStatus } from '#lib/state/list-actions.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { session } from '#lib/state/session.svelte.ts';

	// A season-chart entry, editorial (design/mockups/seasonal-editorial): its
	// popularity rank set large, the cover, then title and studio, when it
	// airs, origin, synopsis, genres and score, ruled off from the next. The
	// cover's colour tints the rank and studio; a title on your list gets an
	// offset shadow behind its cover.

	interface Props {
		card: SeasonCard;
	}

	let { card }: Props = $props();

	const title = $derived(card.title);
	const entry = $derived(session.authState === 'out' ? null : list.entryFor(title));
	/** Text in the title's colour, light enough to read on the page. */
	const ink = $derived(`color-mix(in oklch, ${title.accent} 75%, #fff)`);
	const shade = $derived(`color-mix(in oklch, ${title.accent} 55%, var(--color-canvas))`);

	function setStatus(status: MediaListStatus) {
		if (list.sync) void changeStatus(title, status);
	}
</script>

<article
	class="group relative grid grid-cols-[76px_minmax(0,1fr)] gap-3.5 border-b border-line py-5 sm:grid-cols-[48px_92px_minmax(0,1fr)] sm:gap-4.5"
	style="--ink:{ink}"
	aria-labelledby="season-card-{title.id}"
	data-testid="season-card"
>
	<!-- the rank: AniList's most popular this season (leftovers have none) -->
	{#if card.popularRank}
		<span
			class="hidden font-display text-[44px] leading-[0.85] font-light tracking-[-0.05em] text-dim transition-colors group-hover:text-(--ink) sm:block"
			title="Most popular this season"
			aria-label="Number {card.popularRank} most popular this season"
			>{String(card.popularRank).padStart(2, '0')}</span
		>
	{:else}
		<span class="hidden sm:block"></span>
	{/if}

	<a
		href="/title/{title.id}"
		class="relative aspect-2/3 w-[76px] self-start overflow-hidden transition-shadow duration-(--duration-lift) ease-enter sm:w-[92px]"
		style="background:{title.placeholder};box-shadow:{entry ? `6px 6px 0 ${shade}` : 'none'}"
		tabindex="-1"
		aria-hidden="true"><CoverImage {title} /></a
	>

	<div class="flex min-w-0 flex-col gap-1.5">
		<div class="flex items-start gap-2">
			<div class="flex min-w-0 flex-1 flex-col gap-0.5">
				<h3
					class="m-0 line-clamp-2 text-[16px] leading-snug font-bold tracking-[-0.01em]"
					id="season-card-{title.id}"
				>
					<a href="/title/{title.id}" class="text-ink hover:text-ink hover:underline"
						>{title.title}</a
					>
				</h3>
				<div class="truncate text-[12.5px]">
					{#if card.studio}<span class="font-semibold" style="color:{ink}">{card.studio}</span>
						<span class="text-dim">·</span>{/if}
					<span class="text-muted">{card.origin}</span>
				</div>
			</div>
			{#if session.authState === 'out'}
				<a
					href="/login"
					aria-label="Log in to add {title.title} to your list"
					class="touch-target relative grid h-8 w-8 flex-none place-items-center rounded-full border border-line text-muted hover:border-ink hover:text-ink"
				>
					<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">add</span>
				</a>
			{:else}
				<StatusMenu
					status={entry?.status ?? null}
					isAnime
					onSelect={setStatus}
					variant="add"
					label={entry ? `Change list status of ${title.title}` : `Add ${title.title} to list`}
					onOpenEditor={() => editor.open(title)}
				/>
			{/if}
		</div>

		<div class="truncate font-mono text-[12px] text-muted">
			{card.whenLabel} <span class="text-ink">{card.when}</span>
		</div>

		<p class="m-0 line-clamp-2 text-[13px] leading-relaxed text-dim">
			{card.synopsis || 'No synopsis yet.'}
		</p>

		<div class="mt-auto flex items-baseline gap-3 pt-1 text-[12px]">
			<span class="min-w-0 flex-1 truncate text-dim">{card.genres.join(' / ')}</span>
			{#if card.score}
				<span
					class="flex-none font-mono text-ink"
					title="Average score on AniList"
					aria-label="Average score {card.score}%">{card.score}%</span
				>
			{/if}
		</div>
	</div>
</article>
