<script lang="ts">
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { adaptMedia } from '#lib/anilist/adapt.ts';
	import { STATUS_COLOR, statusLabel } from '#lib/catalog/status.ts';
	import type { Title } from '#lib/catalog/types.ts';
	import {
		fetchAiringWeek,
		fetchListCollection,
		fetchNewManga,
		requestStamp
	} from '#lib/anilist/client.ts';
	import type { AiringSlot, AniListMedia, CollectionEntry } from '#lib/anilist/types.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import SeasonHeader from '#lib/components/seasonal/SeasonHeader.svelte';
	import PosterCard from '#lib/components/shared/PosterCard.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import {
		addDays,
		buildCalendar,
		mondayOf,
		parseWeekParam,
		timezoneLabel,
		toWeekParam,
		weekLabel,
		upcomingFirst,
		type CalendarDay,
		type CalendarSlot
	} from '#lib/page-data/seasonal.ts';
	import { clock } from '#lib/state/clock.svelte.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { changeStatus, plusOne } from '#lib/state/list-actions.ts';
	import { loadListState } from '#lib/state/list-state.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';
	import { session } from '#lib/state/session.svelte.ts';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	// Seasonal & schedule. Anime: a week, not a timetable — seven
	// columns of slots by local air time. Manga: new releases.

	const isAnime = $derived(session.mode === 'anime');
	const signedIn = $derived(session.authState === 'in');
	const authSettled = $derived(session.authState !== 'loading');

	/** Countdowns refresh every 30 s — often enough, without rebuilding the week every second. */
	const now = $derived(new Date(Math.floor(clock.seconds / 30) * 30 * 1000));

	// ── Week (in the URL) ──
	const monday = $derived(parseWeekParam(page.url.searchParams.get('week'), new Date()));
	const isThisWeek = $derived(monday.getTime() === mondayOf(new Date()).getTime());

	function goToWeek(target: Date) {
		const week = mondayOf(target);
		const thisWeek = mondayOf(new Date());
		const qs = week.getTime() === thisWeek.getTime() ? '' : `?week=${toWeekParam(week)}`;
		void goto(qs || page.url.pathname, { reset: false });
	}

	// ── Anime: the week's airings ──
	const week = new Resource<AiringSlot[]>();
	function loadWeek() {
		const start = Math.floor(monday.getTime() / 1000);
		const end = Math.floor(addDays(monday, 7).getTime() / 1000);
		const opts = { signedIn, showAdult: session.showAdultContent };
		return week.load(
			`${start}:${opts.signedIn}:${opts.showAdult}`,
			() => fetchAiringWeek(start, end, opts),
			(slots) => void loadListState([...new Set(slots.map((s) => s.media.id))])
		);
	}

	$effect(() => {
		if (isAnime && authSettled) void loadWeek();
	});

	// The server's signed-out week (first load only) shows until the browser's
	// own arrives. Its week is in UTC, so it can start up to a day off the
	// viewer's: close enough to fill the page for that moment.
	const weekData = $derived(
		week.data ??
			(data.week && Math.abs(data.week.start - monday.getTime() / 1000) < 86400
				? data.week.slots
				: null)
	);

	let mineOnly = $state(false);
	// AniChart's layout: a section per day, today first in this week, and
	// days with nothing airing left out
	const days = $derived(
		weekData
			? buildCalendar(weekData, monday, {
					now,
					titles: signedIn ? 'userPreferred' : 'english',
					entry: (id) => (list.isRemoved(id) ? null : (list.get(id) ?? null)),
					mineOnly: mineOnly && signedIn
				})
			: null
	);
	const shownDays = $derived(days ? upcomingFirst(days).filter((d) => d.slots.length) : []);
	// this week, the days already past fold away under "Earlier this week", so
	// the page reads today onwards instead of Thu → Sun → Mon → Wed
	const folded = $derived(isThisWeek && shownDays.some((d) => !d.past));
	const openDays = $derived(folded ? shownDays.filter((d) => !d.past) : shownDays);
	const pastDays = $derived(folded ? shownDays.filter((d) => d.past) : []);
	const pastEpisodes = $derived(pastDays.reduce((sum, d) => sum + d.slots.length, 0));

	// ── Manga: new releases ──
	const reading = new Resource<CollectionEntry[]>();
	const fresh = new Resource<AniListMedia[]>();
	function loadManga() {
		const opts = { signedIn, showAdult: session.showAdultContent };
		const since = new Date();
		since.setMonth(since.getMonth() - 6);
		void fresh.load(
			`new:${opts.signedIn}:${opts.showAdult}`,
			() => fetchNewManga(since, opts),
			(media) => void loadListState(media.map((m) => m.id))
		);
		const userId = session.user?.id;
		if (signedIn && userId) {
			void reading.load(
				`${userId}:MANGA`,
				() => fetchListCollection(userId, 'MANGA'),
				// titles edited since the copy was requested keep their local values
				(entries) =>
					list.seed(
						entries.map(({ media: _media, ...e }) => e),
						requestStamp(entries)
					)
			);
		}
	}

	$effect(() => {
		// again when a newer copy of the list loaded behind the page
		void list.collectionsVersion;
		if (!isAnime && authSettled) loadManga();
	});

	/** Series you're reading that are still releasing — "your series first". */
	const yourSeries = $derived(
		(reading.data ?? [])
			.filter((e) => {
				const live = list.isRemoved(e.mediaId) ? null : (list.get(e.mediaId) ?? e);
				return (
					live &&
					(live.status === 'CURRENT' || live.status === 'REPEATING') &&
					e.media.status === 'RELEASING'
				);
			})
			.map((e) => adaptMedia(e.media, list.get(e.mediaId) ?? e, { titles: 'userPreferred' }))
	);
	const yourSeriesSummary = $derived(
		`${yourSeries.length} series you're reading ${yourSeries.length === 1 ? 'is' : 'are'} still releasing`
	);
	const newSeries = $derived(
		(fresh.data ?? []).map((m) =>
			adaptMedia(m, undefined, { titles: signedIn ? 'userPreferred' : 'english' })
		)
	);

	const accent = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');

	// "Fall 2026 · week of Oct 5" → the big "Fall 2026" and the quieter rest
	const [seasonTitle, weekOf] = $derived(weekLabel(monday).split(' · '));
	/** "CEST · UTC+2" for the mobile header. */
	const tzShort = $derived(
		timezoneLabel(now)
			.replace('Times in ', '')
			.replace(/^(\S+) \((.+)\)$/, '$1 · $2')
	);

	function planManga(t: Title) {
		if (session.authState === 'out') return void goto('/login');
		void changeStatus(t, 'PLANNING');
	}
</script>

<svelte:head>
	<title>{isAnime ? (data.meta?.headline ?? 'Schedule') : 'New releases'} · miruyo</title>
</svelte:head>

<!-- one day of the week; its heading sticks under the navbar while the day scrolls by -->
{#snippet daySection(day: CalendarDay)}
	<section class="flex flex-col gap-4 lg:gap-5" aria-label="{day.name}, {day.label}">
		<h2
			class="sticky top-14 z-10 m-0 -mx-4 flex items-baseline gap-3 bg-canvas/90 px-4 py-2 font-display backdrop-blur-md lg:top-16 lg:-mx-2 lg:px-2 {day.past
				? 'text-muted'
				: 'text-ink'} text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
		>
			{day.weekday}
			{#if day.isToday}
				<span
					class="rounded-[2px] px-2 py-0.5 font-sans text-xs font-semibold"
					style="background:rgba(255,106,85,.14);color:var(--color-anime-soft)">Today</span
				>
			{/if}
			<span class="font-mono text-sm font-medium text-dim">{day.label}</span>
		</h2>
		<div
			class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 lg:gap-x-8 lg:gap-y-5 xl:grid-cols-4"
		>
			{#each day.slots as slot (slot.key)}
				{@render airingCard(slot)}
			{/each}
		</div>
	</section>
{/snippet}

<!-- an airing, AniChart-style: cover on the left, title, "Ep 9 airing at 23:00";
     your shows glow in their cover colour and carry progress and +1 -->
{#snippet airingCard(slot: CalendarSlot)}
	{@const progress = list.get(slot.title.id)?.progress ?? 0}
	<div
		class="relative flex min-h-[88px] border-b border-line py-2.5"
		style={slot.mine ? `box-shadow:inset 2px 0 0 ${slot.title.accent}` : ''}
		data-testid="airing-slot"
	>
		<a
			href="/title/{slot.title.id}"
			class="relative w-[56px] flex-none overflow-hidden"
			style="background:{slot.title.placeholder}"
			tabindex="-1"
			aria-hidden="true"><CoverImage title={slot.title} /></a
		>
		<div class="flex min-w-0 flex-1 flex-col justify-center gap-1 py-2.5 pr-3 pl-3.5">
			<a
				href="/title/{slot.title.id}"
				class="line-clamp-2 text-[15px] leading-snug font-semibold text-ink hover:text-ink hover:underline"
				title={slot.title.title}>{slot.title.title}</a
			>
			<div class="truncate text-[13px] text-muted">
				{slot.status}{#if slot.until}
					<span
						class="font-mono text-xs"
						style="color:{slot.soon ? 'var(--color-anime-soft)' : 'var(--color-muted)'}"
						>&nbsp;· in {slot.until}</span
					>
				{/if}
			</div>
			{#if slot.mine}
				<div class="font-mono text-xs text-muted">
					{progress}/{slot.title.total ?? '?'}<span class="sr-only"> watched</span>
				</div>
			{/if}
		</div>
		{#if slot.canAddOne}
			<button
				type="button"
				onclick={() => plusOne(slot.title)}
				aria-label="Add one episode to {slot.title.title}"
				class="my-auto mr-3 grid h-10 w-10 flex-none press place-items-center btn-quiet rounded-[2px]"
			>
				<span class="material-symbols-rounded text-[20px]!" aria-hidden="true">add</span>
			</button>
		{/if}
		{#if slot.next}
			<span
				class="absolute top-1.5 right-0 rounded-[2px] bg-anime px-2 py-0.5 text-[11px] font-semibold text-anime-ink"
				>Airing next</span
			>
		{/if}
	</div>
{/snippet}

<!-- manga row: your series get +1, others Plan -->
{#snippet mangaRow(t: Title)}
	{@const entry = session.authState === 'out' ? null : list.entryFor(t)}
	{@const reading = !!entry && (entry.status === 'CURRENT' || entry.status === 'REPEATING')}
	<div
		class="flex items-center gap-4 border-b border-line py-3"
		style={reading ? `box-shadow:0 0 0 1.5px ${t.accent}` : ''}
		data-testid="manga-row"
	>
		<a
			href="/title/{t.id}"
			class="relative aspect-2/3 w-12 flex-none overflow-hidden rounded-[2px]"
			style="background:{t.placeholder}"
			tabindex="-1"
			aria-hidden="true"><CoverImage title={t} /></a
		>
		<div class="flex min-w-0 flex-1 flex-col gap-1">
			<a
				href="/title/{t.id}"
				class="truncate text-[15px] font-semibold text-ink hover:text-ink hover:underline"
				>{t.title}</a
			>
			<div class="truncate text-[13px] text-muted">
				{[t.format, t.status, t.genres.slice(0, 2).join(', ')].filter(Boolean).join(' · ')}
			</div>
		</div>
		{#if reading}
			<div class="hidden font-mono text-sm font-semibold sm:block">CH {entry.progress}</div>
			<button
				type="button"
				onclick={() => plusOne(t)}
				aria-label="Add one chapter to {t.title}"
				class="flex h-10 flex-none press items-center gap-0.5 rounded-[2px] bg-manga px-3 font-mono text-[13px] font-bold text-manga-ink"
			>
				<span class="material-symbols-rounded text-[18px]!" aria-hidden="true">add</span>Read
			</button>
		{:else if entry}
			<span class="flex-none text-[13px] font-semibold" style="color:{STATUS_COLOR[entry.status]}"
				>{statusLabel(entry.status, false)}</span
			>
		{:else}
			<button
				type="button"
				onclick={() => planManga(t)}
				aria-label="Plan {t.title}"
				class="flex h-10 flex-none press items-center gap-1 rounded-[2px] border border-white/12 bg-raised-hover px-3 text-[13px] font-semibold text-ink"
			>
				<span class="material-symbols-rounded text-[18px]!" aria-hidden="true">bookmark_add</span
				>Plan
			</button>
		{/if}
	</div>
{/snippet}

<PageShell nav="seasonal" tab="seasonal">
	{#if isAnime}
		<SeasonHeader active="airing" {now} />

		<!-- desktop header -->
		<div class="hidden items-end gap-6 px-10 pt-9 lg:flex xl:px-20">
			<div class="flex flex-col gap-3">
				<div class="flex items-center gap-1.5">
					<button
						type="button"
						onclick={() => goToWeek(addDays(monday, -7))}
						aria-label="Previous week"
						class="grid h-10 w-10 press place-items-center btn-quiet text-ink"
					>
						<span class="material-symbols-rounded text-[22px]!" aria-hidden="true"
							>chevron_left</span
						>
					</button>
					<button
						type="button"
						onclick={() => goToWeek(addDays(monday, 7))}
						aria-label="Next week"
						class="grid h-10 w-10 press place-items-center btn-quiet text-ink"
					>
						<span class="material-symbols-rounded text-[22px]!" aria-hidden="true"
							>chevron_right</span
						>
					</button>
					{#if !isThisWeek}
						<button
							type="button"
							onclick={() => goToWeek(new Date())}
							class="ml-2 text-sm font-semibold text-muted hover:text-ink"
						>
							Back to this week
						</button>
					{/if}
				</div>
				<h1
					class="m-0 font-display text-[44px] font-medium tracking-[-0.02em]"
					data-testid="week-label"
				>
					{seasonTitle} <span class="font-medium text-dim">· {weekOf}</span>
				</h1>
			</div>
			<div class="flex-1"></div>
			<div class="flex items-center gap-2 text-[13px] text-muted">
				<span class="material-symbols-rounded text-[18px]!" aria-hidden="true">public</span>
				{timezoneLabel(now)}
			</div>
			{#if signedIn}
				<button
					type="button"
					role="switch"
					aria-checked={mineOnly}
					onclick={() => (mineOnly = !mineOnly)}
					class="flex h-10 items-center gap-2 rounded-[2px] border pr-3.5 pl-2.5 text-sm font-semibold whitespace-nowrap"
					style={mineOnly
						? 'background:rgba(255,106,85,.14);border-color:rgba(255,106,85,.45);color:#FFB3A6'
						: 'background:var(--color-raised);border-color:rgba(255,255,255,.1);color:#DDD3C3'}
				>
					<span class="material-symbols-rounded text-[18px]!" aria-hidden="true"
						>{mineOnly ? 'check_box' : 'check_box_outline_blank'}</span
					>
					My list only
				</button>
			{/if}
		</div>

		<!-- mobile header -->
		<div class="flex flex-col gap-2 px-4 pt-3.5 lg:hidden">
			<div class="flex items-center justify-between">
				<div class="font-display text-xl font-[650]">{seasonTitle}</div>
				<div class="text-xs text-dim">{tzShort}</div>
			</div>
			<div class="flex items-center gap-2">
				<button
					type="button"
					onclick={() => goToWeek(addDays(monday, -7))}
					aria-label="Previous week"
					class="grid h-9 w-9 place-items-center btn-quiet text-ink"
				>
					<span class="material-symbols-rounded text-[20px]!" aria-hidden="true">chevron_left</span>
				</button>
				<div class="flex-1 text-center text-[13px] text-muted">{weekOf}</div>
				<button
					type="button"
					onclick={() => goToWeek(addDays(monday, 7))}
					aria-label="Next week"
					class="grid h-9 w-9 place-items-center btn-quiet text-ink"
				>
					<span class="material-symbols-rounded text-[20px]!" aria-hidden="true">chevron_right</span
					>
				</button>
				{#if signedIn}
					<button
						type="button"
						role="switch"
						aria-checked={mineOnly}
						onclick={() => (mineOnly = !mineOnly)}
						aria-label="My list only"
						class="grid h-9 w-9 place-items-center rounded-[2px] border"
						style={mineOnly
							? 'background:rgba(255,106,85,.14);border-color:rgba(255,106,85,.45);color:#FFB3A6'
							: 'background:var(--color-raised);border-color:rgba(255,255,255,.1);color:#DDD3C3'}
					>
						<span class="material-symbols-rounded text-[18px]!" aria-hidden="true"
							>{mineOnly ? 'check_box' : 'check_box_outline_blank'}</span
						>
					</button>
				{/if}
			</div>
		</div>

		<div class="mx-auto max-w-[1680px] px-4 pt-5 pb-16 lg:px-10 lg:pt-9 lg:pb-20 xl:px-20">
			{#if !days && (week.pending || !authSettled)}
				<div class="flex flex-col gap-9" aria-busy="true" aria-label="Loading the week">
					{#each { length: 2 } as _, i (i)}
						<div class="flex flex-col gap-4">
							<Skeleton class="h-7 w-40" />
							<div
								class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 lg:gap-x-8 lg:gap-y-5 xl:grid-cols-4"
							>
								{#each { length: 8 } as __, j (j)}<Skeleton class="h-[88px] rounded-[2px]" />{/each}
							</div>
						</div>
					{/each}
				</div>
			{:else if !days && week.failed}
				<SectionError
					title="Couldn't load the schedule"
					onRetry={loadWeek}
					detail={week.error}
					retryIn={week.retry.active ? week.retry.label : undefined}
					rateLimited={week.rateLimited}
				/>
			{:else if days}
				<div class="flex flex-col gap-9 lg:gap-12" data-testid="week-grid">
					{#each openDays as day (day.label)}
						{@render daySection(day)}
					{:else}
						<p class="m-0 py-16 text-center text-sm text-muted">
							{mineOnly ? 'Nothing of yours airs this week.' : 'Nothing airing this week.'}
						</p>
					{/each}
					{#if pastDays.length}
						<details class="group border-t border-white/6 pt-6">
							<summary
								class="flex cursor-pointer list-none items-center gap-2 text-xs font-semibold tracking-wider text-dim uppercase hover:text-muted [&::-webkit-details-marker]:hidden"
							>
								Earlier this week
								<span class="font-mono font-medium tracking-normal normal-case"
									>· {pastEpisodes} {pastEpisodes === 1 ? 'episode' : 'episodes'}</span
								>
								<span
									class="material-symbols-rounded !text-[18px] transition-transform group-open:rotate-180"
									aria-hidden="true">expand_more</span
								>
							</summary>
							<div class="mt-6 flex flex-col gap-9 lg:gap-12">
								{#each pastDays as day (day.label)}
									{@render daySection(day)}
								{/each}
							</div>
						</details>
					{/if}
				</div>
			{/if}
		</div>
	{:else}
		<!-- manga: new releases -->
		<div
			class="grid gap-10 px-4 pt-5 pb-16 lg:grid-cols-[minmax(0,1fr)_340px] lg:gap-12 lg:px-10 lg:pt-9 lg:pb-20 xl:px-20"
		>
			<div class="flex flex-col gap-7">
				<div class="flex flex-col gap-2">
					<h1
						class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
					>
						New releases
					</h1>
					<p class="m-0 max-w-2xl text-[13px] text-dim">
						AniList doesn't publish chapter release times, so this follows series: yours that are
						still releasing, then series that started serializing recently.
					</p>
				</div>

				{#if signedIn}
					<section class="flex flex-col gap-2.5" aria-labelledby="your-series">
						<h2
							id="your-series"
							class="m-0 text-[11px] font-semibold tracking-wider text-dim uppercase"
						>
							Your series
						</h2>
						{#if reading.pending}
							{#each { length: 3 } as _, i (i)}<Skeleton
									class="h-[96px] w-full rounded-[2px]"
								/>{/each}
						{:else if reading.failed}
							<SectionError
								title="Couldn't load your list"
								onRetry={loadManga}
								detail={reading.error}
								rateLimited={reading.rateLimited}
							/>
						{:else if yourSeries.length}
							{#each yourSeries as t (t.id)}{@render mangaRow(t)}{/each}
						{:else}
							<p class="m-0 text-sm text-muted">
								None of the series you're reading are releasing right now.
							</p>
						{/if}
					</section>
				{/if}

				<section
					class="flex flex-col gap-2.5"
					aria-labelledby="new-series"
					data-testid="new-series"
				>
					<h2
						id="new-series"
						class="m-0 text-[11px] font-semibold tracking-wider text-dim uppercase"
					>
						Newly serialized
					</h2>
					{#if fresh.pending || !authSettled}
						{#each { length: 4 } as _, i (i)}<Skeleton
								class="h-[96px] w-full rounded-[2px]"
							/>{/each}
					{:else if fresh.failed}
						<SectionError
							title="Couldn't load new series"
							onRetry={loadManga}
							detail={fresh.error}
							rateLimited={fresh.rateLimited}
						/>
					{:else}
						{#each newSeries as t (t.id)}{@render mangaRow(t)}{/each}
					{/if}
				</section>
			</div>

			<aside class="flex flex-col gap-3.5 lg:pt-[76px]">
				{#if signedIn && reading.data}
					<div class="flex flex-col gap-2.5 border-t border-ink pt-4">
						<div class="font-display text-lg font-[650]">Your series</div>
						<div class="font-display text-[40px] leading-none font-[650] text-manga-soft">
							{yourSeries.length}
						</div>
						<div class="text-[13px] text-muted" data-testid="your-series-summary">
							{yourSeriesSummary}
						</div>
					</div>
				{:else if !signedIn}
					<div class="flex flex-col gap-2.5 border-t border-ink pt-4">
						<div class="font-display text-lg font-[650]">Follow your series</div>
						<div class="text-[13px] text-muted">
							Log in with AniList to see the series you're reading here first, with one-tap +1.
						</div>
						<a
							href="/login"
							class="mt-1 flex h-10 items-center justify-center rounded-[2px] bg-manga text-sm font-semibold text-manga-ink hover:text-manga-ink"
							>Log in with AniList</a
						>
					</div>
				{/if}
			</aside>
		</div>
	{/if}
</PageShell>
