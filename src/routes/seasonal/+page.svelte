<script lang="ts">
	import { browser } from '$app/env';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { fetchSeasonChart } from '#lib/anilist/client.ts';
	import type { SeasonMedia } from '#lib/anilist/types.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import SeasonCard from '#lib/components/seasonal/SeasonCard.svelte';
	import SeasonHeader from '#lib/components/seasonal/SeasonHeader.svelte';
	import PosterCard from '#lib/components/shared/PosterCard.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import {
		buildSeasonChart,
		CHART_SORTS,
		parseSeasonParams,
		SEASON_NAMES,
		type ChartSort
	} from '#lib/page-data/season-chart.ts';
	import { reveal } from '#lib/motion.ts';
	import { clock } from '#lib/state/clock.svelte.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { loadListState } from '#lib/state/list-state.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';
	import { readPref, writePref } from '#lib/state/prefs.ts';
	import { session } from '#lib/state/session.svelte.ts';
	import { SEASON_VIEW_STORAGE_KEY } from '#lib/storage-keys.ts';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	// The season chart (AniChart's layout): everything premiering in a
	// season, in format sections, plus the leftovers still airing from
	// earlier seasons. Anime only — AniList has no manga seasons.

	// Links from before the week view became /schedule
	$effect(() => {
		const week = page.url.searchParams.get('week');
		if (week) void goto(`/schedule?week=${encodeURIComponent(week)}`, { replace: true });
	});

	// Arriving in manga mode switches to anime; switching to manga here goes
	// to manga's own page, New releases.
	if (browser && session.mode === 'manga') session.setMode('anime');
	$effect(() => {
		if (session.mode === 'manga') void goto('/schedule');
	});

	const signedIn = $derived(session.authState === 'in');
	const authSettled = $derived(session.authState !== 'loading');

	/** Countdowns move once a minute. */
	const now = $derived(new Date(Math.floor(clock.seconds / 60) * 60 * 1000));
	const season = $derived(parseSeasonParams(page.url.searchParams, new Date()));
	const seasonName = $derived(`${SEASON_NAMES[season.season]} ${season.year}`);

	const chart = new Resource<{ media: SeasonMedia[]; leftovers: SeasonMedia[] }>();
	function loadChart() {
		const opts = { signedIn, showAdult: session.showAdultContent };
		const { season: s, year } = season;
		return chart.load(
			`${s}:${year}:${opts.signedIn}:${opts.showAdult}`,
			() => fetchSeasonChart(s, year, opts),
			(data) => void loadListState([...data.media, ...data.leftovers].map((m) => m.id))
		);
	}

	$effect(() => {
		if (authSettled) void loadChart();
	});

	// the server's signed-out chart (first load only) shows until the browser's own arrives
	const chartData = $derived(
		chart.data ??
			(data.chart?.season === season.season && data.chart.year === season.year ? data.chart : null)
	);
	$effect(() => () => chart.reset());

	let sort = $state<ChartSort>('popularity');
	let filter = $state('');
	// cards carry the synopsis, genres and score; posters fit a season on a
	// few screens instead of a dozen
	type View = 'cards' | 'posters';
	let view = $state<View>(readPref(SEASON_VIEW_STORAGE_KEY) === 'posters' ? 'posters' : 'cards');
	function setView(v: View) {
		view = v;
		writePref(SEASON_VIEW_STORAGE_KEY, v);
	}

	const sections = $derived(
		chartData
			? buildSeasonChart(chartData.media, chartData.leftovers, {
					season,
					now,
					titles: signedIn ? 'userPreferred' : 'english',
					sort,
					filter,
					entry: (id) => (list.isRemoved(id) ? null : (list.get(id) ?? null))
				})
			: null
	);
	const total = $derived(chartData?.media.length ?? 0);

	/** The season's kanji for the masthead (秋, autumn), as in a Japanese magazine's season issue. */
	const KANJI: Record<string, string> = {
		WINTER: '冬',
		SPRING: '春',
		SUMMER: '夏',
		FALL: '秋'
	};
	/** Each section's gloss. */
	const GLOSS: Record<string, string> = {
		tv: 'テレビ',
		short: 'ショート',
		leftovers: '継続',
		movie: '劇場',
		other: 'OVA・配信'
	};
</script>

<svelte:head>
	<title>{seasonName} Anime: Every New Show & When It Airs · miruyo</title>
</svelte:head>

<PageShell nav="seasonal" tab="seasonal">
	<SeasonHeader active={season} now={new Date()} />

	<div
		class="mx-auto flex max-w-[2000px] flex-col gap-10 px-4 pt-6 pb-16 lg:gap-14 lg:px-10 lg:pt-10 lg:pb-20 xl:px-20"
	>
		<!-- the masthead: the season's kanji in vermilion, the season set large -->
		<header
			class="flex flex-wrap items-end gap-x-6 gap-y-4 border-b-[3px] border-double border-line pb-6 lg:gap-x-9 lg:pb-8"
		>
			<span
				class="rise font-jp text-[76px] leading-[0.82] font-bold text-anime lg:-mb-1.5 lg:text-[150px]"
				lang="ja"
				aria-hidden="true">{KANJI[season.season]}</span
			>
			<div class="flex min-w-0 flex-1 flex-col gap-3">
				<h1
					class="m-0 rise font-display text-[44px] leading-[0.9] font-light tracking-[-0.045em] [--d:80ms] lg:text-[96px]"
				>
					{SEASON_NAMES[season.season]} <em class="font-semibold italic">{season.year}</em>
				</h1>
				<p class="m-0 max-w-[56ch] rise text-[15px] leading-relaxed text-muted [--d:160ms]">
					{#if chartData}
						<b class="font-semibold text-ink">{total} {total === 1 ? 'title' : 'titles'}</b>
						premiering{#if chartData.leftovers.length},
							<b class="font-semibold text-ink">{chartData.leftovers.length} still airing</b> from earlier
							seasons{/if}. Ranked by how many people on AniList are watching.
					{:else}&nbsp;{/if}
				</p>
			</div>
		</header>

		<!-- tools, as quiet words and underlined fields -->
		<div class="-mt-2 flex flex-wrap items-center gap-x-7 gap-y-3 lg:-mt-4">
			<label
				class="flex h-10 w-full items-center gap-2 border-b border-line text-sm focus-within:border-ink sm:w-64"
			>
				<span class="material-symbols-rounded !text-[20px] text-dim" aria-hidden="true">search</span
				>
				<span class="sr-only">Filter this season</span>
				<input
					bind:value={filter}
					type="search"
					placeholder="Filter this season…"
					class="min-w-0 flex-1 border-0 bg-transparent p-0 text-sm text-ink outline-none placeholder:text-dim focus:ring-0"
				/>
			</label>
			<div class="flex-1"></div>
			<label class="flex h-10 items-center gap-1.5 text-sm">
				<span class="text-dim">Sort</span>
				<select
					bind:value={sort}
					class="h-8 border-0 bg-transparent py-0 pr-8 pl-0 text-sm font-semibold text-ink focus:ring-0"
				>
					{#each CHART_SORTS as s (s.key)}
						<option value={s.key}>{s.label}</option>
					{/each}
				</select>
			</label>
			<div class="flex items-baseline text-sm" role="radiogroup" aria-label="View">
				{#each [{ key: 'cards', label: 'Cards' }, { key: 'posters', label: 'Posters' }] as v, i (v.key)}
					{@const on = view === v.key}
					{#if i}<span class="px-1.5 text-dim" aria-hidden="true">/</span>{/if}
					<button
						type="button"
						role="radio"
						aria-checked={on}
						onclick={() => setView(v.key as View)}
						class="touch-target relative py-2 {on
							? 'font-semibold text-ink shadow-[inset_0_-1.5px_0_var(--color-anime)]'
							: 'text-dim hover:text-ink'}"
					>
						{v.label}
					</button>
				{/each}
			</div>
		</div>

		{#if !sections && (chart.pending || !authSettled)}
			<div class="flex flex-col gap-4" aria-busy="true" aria-label="Loading the season">
				<Skeleton class="h-8 w-20" />
				<div class="grid grid-cols-1 md:grid-cols-2 md:gap-x-10 xl:gap-x-14">
					{#each { length: 6 } as _, i (i)}
						<div class="flex gap-4 border-b border-line py-5">
							<Skeleton class="aspect-2/3 w-[92px] flex-none" />
							<div class="flex flex-1 flex-col gap-2.5 pt-1">
								<Skeleton class="h-4 w-3/4" />
								<Skeleton class="h-3 w-1/2" />
								<Skeleton class="h-3 w-full" />
							</div>
						</div>
					{/each}
				</div>
			</div>
		{:else if !sections && chart.failed}
			<SectionError
				title="Couldn't load {seasonName}"
				onRetry={loadChart}
				detail={chart.error}
				retryIn={chart.retry.active ? chart.retry.label : undefined}
				rateLimited={chart.rateLimited}
			/>
		{:else if sections}
			{#each sections as section (section.key)}
				<section class="flex flex-col gap-4 lg:gap-5" aria-labelledby="section-{section.key}">
					<div class="flex items-baseline gap-3">
						<h2
							class="m-0 flex items-baseline gap-3 font-display text-[26px] font-medium tracking-[-0.02em] lg:text-[32px]"
							id="section-{section.key}"
						>
							{section.label}
							<span class="font-mono text-sm font-normal text-dim">{section.cards.length}</span>
						</h2>
						{#if GLOSS[section.key]}
							<span class="hidden font-jp text-[13px] text-dim sm:inline" lang="ja"
								>{GLOSS[section.key]}</span
							>
						{/if}
						<span class="draw h-px flex-1 self-center bg-line" aria-hidden="true" {@attach reveal}
						></span>
					</div>
					{#if view === 'posters'}
						<div
							class="grid grid-cols-3 gap-x-3 gap-y-5 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6 lg:gap-x-5 lg:gap-y-7 xl:grid-cols-8"
						>
							{#each section.cards as card (card.title.id)}
								<PosterCard
									title={card.title}
									size="sm"
									countdown
									loggedOut={session.authState === 'out'}
								/>
							{/each}
						</div>
					{:else}
						<!-- ruled entries, two columns from tablets (three on very wide screens) -->
						<div
							class="-mt-4 grid grid-cols-1 min-[1800px]:grid-cols-3 md:grid-cols-2 md:gap-x-10 lg:-mt-5 xl:gap-x-14"
						>
							{#each section.cards as card (card.title.id)}
								<SeasonCard {card} />
							{/each}
						</div>
					{/if}
				</section>
			{:else}
				<p class="m-0 py-16 text-center text-sm text-muted">
					{filter
						? `Nothing in ${seasonName} matches “${filter}”.`
						: `Nothing announced for ${seasonName} yet.`}
				</p>
			{/each}
		{/if}
	</div>
</PageShell>
