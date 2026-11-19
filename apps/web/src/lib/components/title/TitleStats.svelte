<script lang="ts">
	import { fetchTitleStats } from '#lib/anilist/client.ts';
	import type { TitleStatsResponse } from '#lib/anilist/types.ts';
	import { STATUS_COLOR } from '#lib/catalog/status.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import { buildTitleStats } from '#lib/page-data/title-stats.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';

	// A title's Stats tab: where it ranks, how many people have it on each
	// list, and how they score it, from AniList's counts across every user.
	// It loads when the tab opens (TITLE_STATS_QUERY). The bars take the
	// title's own colour, as the rest of the page does.

	interface Props {
		id: number;
		isAnime: boolean;
		/** The cover's colour (Title.accent). */
		accent: string;
	}

	let { id, isAnime, accent }: Props = $props();

	const stats = new Resource<TitleStatsResponse['Media']>();
	$effect(() => {
		const mediaId = id;
		void stats.load(String(mediaId), () => fetchTitleStats(mediaId));
	});
	$effect(() => () => stats.reset());

	const view = $derived(stats.data ? buildTitleStats(stats.data, { isAnime }) : null);
	const unit = $derived(isAnime ? 'anime' : 'manga');
</script>

{#snippet heading(text: string, id: string, aside = '')}
	<div class="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
		<h2 {id} class="m-0 font-display text-[26px] font-medium tracking-[-0.02em] whitespace-nowrap">
			{text}
		</h2>
		{#if aside}<div class="text-[13px] text-muted">{aside}</div>{/if}
	</div>
{/snippet}

{#if stats.failed}
	<SectionError
		title="Couldn't load this {unit}'s stats"
		onRetry={() => stats.load(String(id), () => fetchTitleStats(id))}
		detail={stats.error}
		retryIn={stats.retry.active ? stats.retry.label : undefined}
		rateLimited={stats.rateLimited}
	/>
{:else if !view}
	<div class="flex flex-col gap-4" aria-busy="true" aria-label="Loading stats">
		<Skeleton class="h-24" />
		<Skeleton class="h-40" />
		<Skeleton class="h-64" />
	</div>
{:else}
	{#if view.rankings.length}
		<section class="flex flex-col gap-4" aria-labelledby="stats-rankings">
			{@render heading('Rankings', 'stats-rankings')}
			<ul class="m-0 grid list-none grid-cols-2 gap-2 p-0 xl:grid-cols-3">
				{#each view.rankings as r (r.key)}
					<li>
						<svelte:element
							this={r.href ? 'a' : 'div'}
							href={r.href}
							class="flex h-full flex-col gap-1.5 border-b border-line py-3 text-ink sm:flex-row sm:items-center sm:gap-3.5 {r.href
								? 'hover:bg-raised-hover hover:text-ink'
								: ''}"
						>
							<span
								class="font-mono text-xl leading-none font-bold sm:min-w-[3.5ch]"
								style="color:{accent}">#{r.rank}</span
							>
							<span class="flex min-w-0 flex-col gap-0.5">
								<span class="text-sm font-semibold">{r.label}</span>
								<span class="text-xs text-muted">{r.when} · {r.format}</span>
							</span>
						</svelte:element>
					</li>
				{/each}
			</ul>
		</section>
	{/if}

	{#if view.statuses.length}
		<section
			class="flex flex-col gap-4"
			aria-labelledby="stats-statuses"
			data-testid="title-status-stats"
		>
			{@render heading('On lists', 'stats-statuses', `${view.members} people`)}
			<div class="flex flex-col gap-3.5 border-t border-ink pt-5">
				<div class="flex h-3 gap-0.5 overflow-hidden" aria-hidden="true">
					{#each view.statuses as s (s.status)}
						<div class="h-full" style="flex:{s.count};background:{STATUS_COLOR[s.status]}"></div>
					{/each}
				</div>
				<ul
					class="m-0 grid list-none grid-cols-2 gap-x-4 gap-y-2.5 p-0 sm:grid-cols-3 lg:grid-cols-5"
				>
					{#each view.statuses as s (s.status)}
						<li class="flex flex-col gap-0.5">
							<span class="flex items-center gap-1.5 text-xs text-muted">
								<span
									class="h-2 w-2 rounded-full"
									style="background:{STATUS_COLOR[s.status]}"
									aria-hidden="true"
								></span>
								{s.label}
							</span>
							<span class="font-mono text-base font-semibold text-ink"
								>{s.shown}
								<span class="text-xs font-medium text-dim">{s.percent}%</span></span
							>
						</li>
					{/each}
				</ul>
			</div>
		</section>
	{/if}

	<section
		class="flex flex-col gap-4"
		aria-labelledby="stats-scores"
		data-testid="title-score-stats"
	>
		{@render heading(
			'Score distribution',
			'stats-scores',
			view.average ? `Average ${view.average} · ${view.scored} scores` : ''
		)}
		<div class="border-t border-ink pt-5">
			{#if view.scores.some((b) => b.count)}
				<div
					class="grid h-[140px] grid-cols-10 items-end gap-1.5 pt-5 lg:h-52 lg:gap-2.5 lg:bg-[repeating-linear-gradient(0deg,rgba(255,255,255,.06)_0_1px,transparent_1px_52px)]"
					role="list"
					aria-label="People per score, 1 to 10"
				>
					{#each view.scores as b, i (b.score)}
						<div
							class="group relative flex h-full flex-col items-center justify-end"
							role="listitem"
							aria-label="{b.count.toLocaleString('en-US')} scored it {b.score}"
						>
							<div
								class="w-full grow-y transition-[height,background] duration-300 ease-enter group-hover:!bg-ink"
								style="--d:{i * 35}ms;height:{b.height || 1}%;background:{b.count
									? accent
									: 'rgba(255,255,255,.08)'}"
							></div>
							<div
								class="pointer-events-none absolute -top-2 left-1/2 z-10 hidden -translate-x-1/2 -translate-y-full rounded-[2px] border border-line bg-raised px-2.5 py-1.5 text-xs whitespace-nowrap shadow-lg group-hover:block"
							>
								<b class="font-mono">{b.count.toLocaleString('en-US')}</b> scored it {b.score}
							</div>
						</div>
					{/each}
				</div>
				<div class="mt-2 grid grid-cols-10 gap-1.5 lg:gap-2.5" aria-hidden="true">
					{#each view.scores as b (b.score)}
						<div class="text-center font-mono text-[11px] font-medium text-dim lg:text-xs">
							{b.score}
						</div>
					{/each}
				</div>
			{:else}
				<p class="m-0 text-sm text-muted">No one has scored it on AniList yet.</p>
			{/if}
		</div>
	</section>
{/if}
