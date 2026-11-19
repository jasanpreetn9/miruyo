<script lang="ts">
	import HeroCarousel from '#lib/components/home/HeroCarousel.svelte';
	import ContinueSection from '#lib/components/home/ContinueSection.svelte';
	import PosterRow from '#lib/components/shared/PosterRow.svelte';
	import UpcomingRow from '#lib/components/home/UpcomingRow.svelte';
	import ForYouRow from '#lib/components/home/ForYouRow.svelte';
	import { localDay, tunePicks } from '#lib/page-data/for-you.ts';
	import { dismissed, loadForYou, tune, type ForYou } from '#lib/state/for-you.svelte.ts';
	import EmptyListOnboarding from '#lib/components/home/EmptyListOnboarding.svelte';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import HomeSkeleton from '#lib/components/home/HomeSkeleton.svelte';
	import HomeMasthead from '#lib/components/home/HomeMasthead.svelte';
	import SectionHeading from '#lib/components/shared/SectionHeading.svelte';
	import LoggedOutHero from '#lib/components/home/LoggedOutHero.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import { fetchHomeFeed, fetchHomeList } from '#lib/anilist/client.ts';
	import type { HomeFeedResponse, HomeListResponse } from '#lib/anilist/types.ts';
	import {
		continueHeading,
		createContinueContent,
		createFeedContent,
		heroPicks,
		type HeroPick
	} from '#lib/page-data/home.ts';
	import { SEASON_NAMES, seasonHref, shiftSeason } from '#lib/page-data/season-chart.ts';
	import { seasonOf } from '#lib/page-data/seasonal.ts';
	import { addToPrefSet, readPrefSet } from '#lib/state/prefs.ts';
	import { toast } from '#lib/state/toast.svelte.ts';
	import { isInProgress } from '#lib/catalog/status.ts';
	import { clock } from '#lib/state/clock.svelte.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';
	import { entryFromTitle, list, type SeedEntry } from '#lib/state/list.svelte.ts';
	import { mediaTypeFor, session, type Mode } from '#lib/state/session.svelte.ts';
	import { QUICK_PICK_SKIPPED_STORAGE_KEY } from '#lib/storage-keys.ts';

	// Two independent sections: a failure only takes down its own part of the
	// page, and the other keeps showing (design 1e).
	const homeList = new Resource<HomeListResponse>();
	const homeFeed = new Resource<HomeFeedResponse>();

	// Refetch whenever auth settles to 'in', or the mode preference changes
	// while already logged in.
	$effect(() => {
		const mode = session.mode;
		const userId = session.user?.id;
		if (session.authState === 'in' && userId) {
			loadList(userId, mode);
			loadFeed(String(userId), mode);
		} else if (session.authState === 'out') {
			// the rows aren't personal, so signed-out visitors get them too
			loadFeed('out', mode);
		}
	});

	$effect(() => () => {
		homeList.reset();
		homeFeed.reset();
	});

	function loadList(userId: number, mode: Mode) {
		// titles edited after the request starts keep their local values
		let since = 0;
		return homeList.load(
			`${userId}:${mode}`,
			() => {
				since = list.stamp();
				return fetchHomeList(userId, mediaTypeFor(mode));
			},
			(data) =>
				list.seed(
					[...data.continueList.mediaList, ...(data.upNext?.mediaList ?? [])].map((entry) => ({
						id: entry.id,
						mediaId: entry.media.id,
						status: entry.status,
						progress: entry.progress
					})),
					since
				)
		);
	}

	/** `viewer`: the user id, or 'out' for the public rows. */
	function loadFeed(viewer: string, mode: Mode) {
		let since = 0;
		return homeFeed.load(
			`${viewer}:${mode}`,
			() => {
				since = list.stamp();
				return fetchHomeFeed(mediaTypeFor(mode));
			},
			(data) => {
				// every feed title carries the viewer's own entry, if any
				const entries: SeedEntry[] = [];
				for (const media of [
					...data.trending.media,
					...data.popularThisSeason.media,
					...data.upcoming.media
				]) {
					const own = media.mediaListEntry;
					if (own) {
						entries.push({
							id: own.id,
							mediaId: media.id,
							status: own.status,
							progress: own.progress
						});
					}
				}
				list.seed(entries, since);
			}
		);
	}

	function retryList() {
		if (session.user) loadList(session.user.id, session.mode);
	}

	function retryFeed() {
		if (session.user) loadFeed(String(session.user.id), session.mode);
		else if (session.authState === 'out') loadFeed('out', session.mode);
	}

	// titles taken off the list this visit drop out of Continue right away
	const inProgress = $derived(
		homeList.data?.continueList.mediaList.filter((e) => !list.isRemoved(e.media.id)) ?? []
	);
	const continueContent = $derived(
		homeList.data
			? createContinueContent(
					inProgress,
					session.mode,
					(id) => list.get(id),
					clock.seconds,
					homeList.data.upNext?.mediaList.filter((e) => !list.isRemoved(e.media.id)) ?? []
				)
			: null
	);
	const signedOut = $derived(session.authState === 'out');
	/** Upcoming's "See all": next season's chart. */
	const nextSeasonHref = seasonHref(shiftSeason(seasonOf(new Date()), 1), new Date());
	const feed = $derived(
		homeFeed.data
			? createFeedContent(homeFeed.data, session.mode, {
					// signed out there's no account title preference, so English
					titles: signedOut ? 'english' : 'userPreferred'
				})
			: null
	);
	// what you're already watching is in Continue: not again here
	const popularTitles = $derived(
		feed?.popularTitles.filter((t) => {
			const status = list.entryFor(t)?.status;
			return !status || !isInProgress(status);
		}) ?? []
	);

	// An empty list (not just nothing in progress) gets the quick-pick card
	// instead of a bare page, until it's skipped (design 1d).
	let skippedQuickPick = $state(readPrefSet(QUICK_PICK_SKIPPED_STORAGE_KEY));
	const quickPickKey = $derived(`${session.user?.id}:${session.mode}`);
	const listIsEmpty = $derived(
		!!homeList.data &&
			homeList.data.anyEntry.mediaList.length === 0 &&
			homeList.data.continueList.mediaList.length === 0
	);
	const showQuickPick = $derived(listIsEmpty && !skippedQuickPick.has(quickPickKey));

	// ── For You: picks from titles you rated highly (signed in only) ──
	const forYou = new Resource<ForYou>();
	// a new day brings new seeds, a page left open overnight included
	const today = $derived(localDay(new Date(clock.seconds * 1000)));
	$effect(() => {
		// again when a newer copy of a list loaded behind the page
		void list.collectionsVersion;
		const userId = session.user?.id;
		const mode = session.mode;
		if (session.authState !== 'in' || !userId) return;
		const scoreFormat = session.scoreFormat;
		const showAdult = session.showAdultContent;
		const day = today;
		void forYou.load(`${userId}:${mode}:${day}`, () =>
			loadForYou({ userId, type: mediaTypeFor(mode), scoreFormat, showAdult, day })
		);
	});
	const forYouPicks = $derived(
		forYou.data && !forYou.data.coldStart
			? tunePicks(forYou.data.picks, tune.value).filter((p) => !dismissed.ids.has(p.title.id))
			: []
	);

	// ── The hero recommends: For You's picks, else the season's most popular ──
	const thisSeason = seasonOf(new Date());
	const thisSeasonName = `${SEASON_NAMES[thisSeason.season]} ${thisSeason.year}`;
	/** For You has answered (picks, too few ratings, or an error): no popular-then-picks swap. */
	const forYouSettled = $derived(!!forYou.data || forYou.failed);
	const heroes = $derived(
		forYouSettled
			? heroPicks(forYouPicks, feed?.popularTitles ?? [], {
					season: thisSeasonName,
					fallbackReason:
						session.mode === 'anime' ? `Popular in ${thisSeasonName}` : 'Popular releasing',
					onList: (t) => !!list.entryFor(t)
				})
			: []
	);
	/** The hero shows the popular titles: their row would repeat it. */
	const heroIsPopular = $derived(heroes.length > 0 && !heroes[0].pick);
	/** For You rows leave out what the hero already shows. */
	const rowPicks = $derived(
		forYouPicks.filter((p) => !heroes.some((h) => h.title.id === p.title.id))
	);

	function hidePick(hero: HeroPick) {
		dismissed.add(hero.title.id);
		toast.show({
			message: `Hid ${hero.title.title} from your picks`,
			action: { label: 'Undo', run: () => dismissed.remove(hero.title.id) }
		});
	}

	function skipQuickPick() {
		addToPrefSet(QUICK_PICK_SKIPPED_STORAGE_KEY, quickPickKey);
		skippedQuickPick = readPrefSet(QUICK_PICK_SKIPPED_STORAGE_KEY);
	}
</script>

{#snippet feedRows()}
	{#if homeFeed.pending}
		<section class="flex flex-col gap-3.5 px-4 lg:px-0" aria-busy="true">
			<Skeleton class="h-6 w-44" />
			<div class="flex gap-3 overflow-hidden lg:grid lg:grid-cols-7 lg:gap-5">
				{#each { length: 7 } as _, i (i)}
					<Skeleton class="aspect-2/3 w-32 flex-none rounded-[2px] lg:w-auto" />
				{/each}
			</div>
		</section>
	{:else if homeFeed.failed}
		<section class="flex flex-col gap-3.5 px-4 lg:px-0" data-testid="feed-error">
			<h3 class="m-0 font-display text-[22px] font-medium tracking-[-0.02em] lg:text-[30px]">
				Trending now
			</h3>
			<SectionError
				title="Couldn't load these rows"
				onRetry={retryFeed}
				detail={homeFeed.error}
				retryIn={homeFeed.retry.active ? homeFeed.retry.label : undefined}
				rateLimited={homeFeed.rateLimited}
			/>
		</section>
	{:else if feed}
		<!-- signed out it's the first row of covers (signed in, the hero leads) -->
		<PosterRow
			heading="Trending now"
			titles={feed.trendingTitles}
			seeAllHref="/browse?sort=trending"
			lead={signedOut}
		/>
		{#if !heroIsPopular}
			<PosterRow
				heading={feed.popularHeading}
				subtitle={feed.popularSubtitle}
				titles={popularTitles}
				seeAllHref={session.mode === 'anime' ? '/seasonal' : '/browse?status=RELEASING'}
				countdown
			/>
		{/if}
		<UpcomingRow
			heading={feed.upcomingHeading}
			items={feed.upcomingItems}
			seeAllHref={session.mode === 'anime' ? nextSeasonHref : '/schedule'}
		/>
	{/if}
{/snippet}

<!-- Picked for you; a hero-sized placeholder while For You answers, so the
     page doesn't jump when it lands -->
{#snippet hero()}
	{#if heroes.length}
		<SectionHeading
			heading={heroes[0].pick ? 'Picked for you' : `Popular in ${thisSeasonName}`}
			jp={heroes[0].pick ? 'おすすめ' : '人気'}
			level="h2"
			class="mb-2 px-4 lg:mb-0 lg:px-10 xl:px-20"
		/>
		<HeroCarousel {heroes} onDismiss={hidePick} />
	{:else if !forYouSettled}
		<div class="px-4 lg:px-0" aria-busy="true" aria-label="Loading picks">
			<Skeleton class="h-[176px] lg:h-[400px]" />
		</div>
	{/if}
{/snippet}

<svelte:head>
	<title>miruyo</title>
</svelte:head>

<PageShell nav="home" tab="home">
	{#if session.authState === 'loading' || (session.authState === 'in' && homeList.pending)}
		<HomeSkeleton />
	{:else if session.authState === 'out'}
		<LoggedOutHero />
		<div class="flex flex-col gap-10 pb-16 lg:gap-14 lg:px-10 xl:px-20">
			{@render feedRows()}
		</div>
	{:else if session.authState === 'error'}
		<!-- still signed in (the token is kept); AniList just couldn't be reached -->
		<div class="px-4 pt-10 lg:px-10 xl:px-20">
			<SectionError
				onRetry={() => session.loadCurrentUser()}
				detail={session.loadError}
				retryIn={session.retry.active ? session.retry.label : undefined}
				rateLimited={session.rateLimited}
			/>
		</div>
	{:else if showQuickPick}
		<EmptyListOnboarding
			titles={feed?.trendingTitles.slice(0, 6) ?? []}
			onSkip={skipQuickPick}
			onAdded={retryList}
		/>
	{:else}
		<!-- editorial (design/mockups/home-editorial): the masthead says where you
		     stand, Continue follows (logging an episode is what you open it for),
		     then the pick and the rows -->
		<HomeMasthead
			content={continueContent}
			isAnime={session.mode === 'anime'}
			season={thisSeasonName}
		/>
		<div class="flex flex-col pb-16">
			<div class="order-2 mt-12 empty:hidden lg:mt-16">{@render hero()}</div>

			<div class="order-1 pt-8 lg:px-10 lg:pt-12 xl:px-20">
				{#if homeList.failed}
					<section class="flex flex-col gap-3.5 px-4 lg:px-0" data-testid="continue-error">
						<h3 class="m-0 font-display text-[22px] font-medium tracking-[-0.02em] lg:text-[30px]">
							{continueHeading(session.mode)}
						</h3>
						<SectionError
							onRetry={retryList}
							detail={homeList.error}
							retryIn={homeList.retry.active ? homeList.retry.label : undefined}
							rateLimited={homeList.rateLimited}
						/>
					</section>
				{:else if continueContent && (continueContent.continueItems.length || continueContent.caughtUp || continueContent.paused.length || continueContent.upNext.length)}
					<ContinueSection
						items={continueContent.continueItems}
						caughtUp={continueContent.caughtUp}
						paused={continueContent.paused}
						upNext={continueContent.upNext}
						isAnime={session.mode === 'anime'}
						title={continueContent.continueHeading}
						summary={continueContent.summary}
						summaryFresh={continueContent.summaryFresh}
					/>
				{:else if continueContent}
					<!-- on the list, but nothing in progress -->
					<section class="flex flex-col gap-3.5 px-4 lg:px-0">
						<h3 class="m-0 font-display text-[22px] font-medium tracking-[-0.02em] lg:text-[30px]">
							{continueContent.continueHeading}
						</h3>
						<div
							class="flex flex-wrap items-center gap-3 border-y border-line py-4 text-sm text-muted"
						>
							<span class="material-symbols-rounded !text-[22px] text-dim" aria-hidden="true"
								>inventory_2</span
							>
							<span class="flex-1">
								Nothing in progress. Start something from your Planning list, or find what's airing.
							</span>
							<a href="/schedule" class="font-semibold">See what's airing →</a>
						</div>
					</section>
				{/if}
			</div>

			<div class="order-3 mt-12 flex flex-col gap-12 lg:mt-16 lg:gap-16 lg:px-10 xl:px-20">
				{#if rowPicks.length}
					<ForYouRow picks={rowPicks} />
				{/if}

				{@render feedRows()}
			</div>
		</div>
	{/if}
</PageShell>
