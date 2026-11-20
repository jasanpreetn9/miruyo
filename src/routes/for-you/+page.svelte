<script lang="ts">
	import SectionError from '#lib/components/home/SectionError.svelte';
	import PosterCard from '#lib/components/shared/PosterCard.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import {
		localDay,
		MIN_RATINGS,
		pickGenres,
		reasonFor,
		scoreLabel,
		tunePicks,
		type Pick
	} from '#lib/page-data/for-you.ts';
	import { clock } from '#lib/state/clock.svelte.ts';
	import { dismissed, loadForYou, tune, type ForYou } from '#lib/state/for-you.svelte.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';
	import { mediaTypeFor, session } from '#lib/state/session.svelte.ts';
	import { toast } from '#lib/state/toast.svelte.ts';

	// For You: picks from AniList's recommendations for the
	// titles you rated highest, and the other mode's version of titles you
	// loved, each with its reason; a seed rail filters to "because of X";
	// "Not this" hides a pick for good; "Tune picks" leaves some out.

	const isAnime = $derived(session.mode === 'anime');
	const forYou = new Resource<ForYou>();

	// a new day brings new seeds, a page left open overnight included
	const today = $derived(localDay(new Date(clock.seconds * 1000)));

	function load() {
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
	}
	$effect(load);

	/** The seed the grid is filtered to, or null for every pick. */
	let seedFilter = $state<number | null>(null);
	$effect(() => {
		// a new mode brings new seeds
		void session.mode;
		seedFilter = null;
	});

	const data = $derived(forYou.data);
	/** Every seed on the rail: this list's, then the other list's. */
	const allSeeds = $derived.by(() => {
		const own = data?.seeds ?? [];
		const ids = new Set(own.map((s) => s.id));
		return [...own, ...(data?.crossSeeds ?? []).filter((s) => !ids.has(s.id))];
	});
	const tuned = $derived(
		tunePicks(data?.picks ?? [], tune.value).filter((p) => !dismissed.ids.has(p.title.id))
	);
	const picks = $derived(
		tuned.filter((p) => seedFilter === null || p.seedIds.includes(seedFilter))
	);
	const filterSeed = $derived(allSeeds.find((s) => s.id === seedFilter) ?? null);
	/** The genres Tune offers: every one among today's picks, and any already left out. */
	const genres = $derived([
		...new Set([...pickGenres(data?.picks ?? []), ...tune.value.hiddenGenres])
	]);
	let tuneOpen = $state(false);
	/** Cross seeds only show while their picks can. */
	const railSeeds = $derived(
		tune.value.crossMode ? allSeeds : allSeeds.filter((s) => s.type === mediaTypeFor(session.mode))
	);

	function notThis(pick: Pick) {
		dismissed.add(pick.title.id);
		toast.show({
			message: `Hid ${pick.title.title} from your picks`,
			action: { label: 'Undo', run: () => dismissed.remove(pick.title.id) }
		});
	}
</script>

<svelte:head>
	<title>For You · miruyo</title>
</svelte:head>

<PageShell tab="home" pad="pb-28 lg:pb-0">
	<div class="flex flex-col gap-6 px-4 pt-6 pb-16 lg:gap-8 lg:px-10 lg:pt-10 xl:px-20">
		<div class="flex flex-col gap-1.5">
			<h1
				class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				For You
			</h1>
			<p class="m-0 max-w-2xl text-sm text-muted">
				Picks from AniList's recommendations for {isAnime ? 'anime' : 'manga'} you rated highly — a different
				handful each day — leaning toward the genres and studios you score well, plus the {isAnime
					? 'anime of manga'
					: 'manga of anime'} you loved. Each says why it's here.
			</p>
		</div>

		{#if session.authState === 'out' || (data?.coldStart ?? false)}
			<!-- cold start -->
			<div
				class="flex flex-col items-start gap-3 border-y-[3px] border-double border-line py-6 lg:max-w-xl lg:py-8"
				data-testid="for-you-cold-start"
			>
				<span class="material-symbols-rounded !text-[32px] text-anime-soft" aria-hidden="true"
					>auto_awesome</span
				>
				<h2
					class="m-0 font-display text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
				>
					Picks get good after {MIN_RATINGS} ratings
				</h2>
				<p class="m-0 text-sm text-muted">
					{#if session.authState === 'out'}
						Log in with AniList and miruyo picks what to {isAnime ? 'watch' : 'read'} next from what you've
						rated, with the reason for each.
					{:else}
						You've rated {data?.scored ?? 0} of {MIN_RATINGS}. Score a few titles you've finished
						and your picks show up here.
					{/if}
				</p>
				<div class="mt-1 flex flex-wrap gap-2.5">
					{#if session.authState === 'out'}
						<a href="/login" class="flex h-11 items-center btn-ink px-4 text-sm hover:text-canvas"
							>Log in with AniList</a
						>
					{:else}
						<a
							href="/list?tab=completed"
							class="flex h-11 items-center btn-ink px-4 text-sm hover:text-canvas"
							>Rate a few titles instead</a
						>
					{/if}
					<a
						href="/browse?sort=trending"
						class="flex h-11 items-center btn-quiet px-4 text-sm font-semibold text-ink hover:text-ink"
						>See what's trending</a
					>
				</div>
			</div>
		{:else if forYou.failed || session.authState === 'error'}
			<SectionError
				title="Couldn't load your picks"
				onRetry={() => (session.authState === 'error' ? session.loadCurrentUser() : load())}
				detail={forYou.error || session.loadError}
				retryIn={forYou.retry.active ? forYou.retry.label : undefined}
				rateLimited={forYou.rateLimited}
			/>
		{:else if !data}
			<div class="flex flex-col gap-5" aria-busy="true" aria-label="Loading your picks">
				<div class="flex gap-2 overflow-hidden">
					{#each { length: 6 } as _, i (i)}<Skeleton
							class="h-12 w-40 flex-none rounded-[2px]"
						/>{/each}
				</div>
				<div
					class="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7"
				>
					{#each { length: 14 } as _, i (i)}<Skeleton class="aspect-2/3 rounded-[2px]" />{/each}
				</div>
			</div>
		{:else}
			{#if !data.seeds.length}
				<!-- too few ratings on this list for picks of its own: these come from the other -->
				<p class="m-0 -mt-2 text-sm text-muted" data-testid="for-you-cross-only">
					You've rated {data.scored} of {MIN_RATINGS}
					{isAnime ? 'anime' : 'manga'}, so for now these are the {isAnime
						? 'anime of manga'
						: 'manga behind anime'} you loved. Rate a few {isAnime ? 'anime' : 'manga'} for picks of their
					own.
				</p>
			{/if}

			<!-- Tune picks: what to leave out, kept on this device -->
			<section class="flex flex-col gap-3" aria-label="Tune picks" data-testid="for-you-tune">
				<div class="flex flex-wrap items-center gap-2.5">
					<button
						type="button"
						onclick={() => (tuneOpen = !tuneOpen)}
						aria-expanded={tuneOpen}
						aria-controls="tune-panel"
						class="flex h-10 items-center gap-1.5 rounded-[2px] border px-3.5 text-sm font-semibold {tune.changed
							? 'border-ink text-ink'
							: 'border-line text-muted hover:border-ink hover:text-ink'}"
					>
						<span class="material-symbols-rounded !text-[18px]" aria-hidden="true">tune</span>
						Tune picks
					</button>
					{#if tune.changed}
						<span class="text-[13px] text-dim">
							{tuned.length} of {data.picks.filter((p) => !dismissed.ids.has(p.title.id)).length} picks
							shown
						</span>
						<button
							type="button"
							onclick={() => tune.reset()}
							class="h-10 px-1 text-sm font-semibold text-muted hover:text-ink">Reset</button
						>
					{/if}
				</div>
				{#if tuneOpen}
					<div
						id="tune-panel"
						class="flex flex-col gap-4 border-t border-ink pt-4 lg:max-w-3xl lg:pt-5"
					>
						<label class="flex min-h-11 cursor-pointer items-center justify-between gap-4">
							<span class="flex flex-col gap-0.5">
								<span class="text-sm font-semibold text-ink">Only titles that are out</span>
								<span class="text-xs text-muted">Leave out what hasn't started yet.</span>
							</span>
							<input
								type="checkbox"
								class="h-5 w-5 flex-none accent-anime"
								checked={tune.value.outOnly}
								onchange={(e) => tune.set({ outOnly: e.currentTarget.checked })}
							/>
						</label>
						<label class="flex min-h-11 cursor-pointer items-center justify-between gap-4">
							<span class="flex flex-col gap-0.5">
								<span class="text-sm font-semibold text-ink">
									{isAnime ? 'Anime of manga' : 'Manga of anime'} you loved
								</span>
								<span class="text-xs text-muted">
									From your {isAnime ? 'manga' : 'anime'} list: the {isAnime
										? 'anime of a manga'
										: 'manga or novel behind an anime'} you rated highly.
								</span>
							</span>
							<input
								type="checkbox"
								class="h-5 w-5 flex-none accent-anime"
								checked={tune.value.crossMode}
								onchange={(e) => tune.set({ crossMode: e.currentTarget.checked })}
							/>
						</label>
						{#if genres.length}
							<div class="flex flex-col gap-2">
								<span class="text-sm font-semibold text-ink">Leave out genres</span>
								<div class="flex flex-wrap gap-1.5" role="group" aria-label="Genres to leave out">
									{#each genres as genre (genre)}
										{@const hidden = tune.value.hiddenGenres.includes(genre)}
										<button
											type="button"
											onclick={() => tune.toggleGenre(genre)}
											aria-pressed={hidden}
											class="flex h-9 items-center gap-1 rounded-[2px] border px-3 text-[13px] {hidden
												? 'border-[rgba(255,138,120,.35)] bg-[rgba(255,138,120,.08)] text-[#FF8A78] line-through'
												: 'border-line bg-surface text-[#DDD3C3] hover:text-ink'}"
										>
											{#if hidden}<span
													class="material-symbols-rounded !text-[15px]"
													aria-hidden="true">block</span
												>{/if}
											{genre}
										</button>
									{/each}
								</div>
							</div>
						{/if}
					</div>
				{/if}
			</section>

			<!-- seed rail: the titles driving the picks; tap one to filter -->
			<div class="flex flex-col gap-2.5">
				<h2 class="m-0 text-xs font-semibold tracking-wider text-dim uppercase">
					Because you rated
				</h2>
				<div
					class="-mx-4 flex scrollbar-none gap-2 overflow-x-auto px-4 lg:mx-0 lg:flex-wrap lg:px-0"
					role="group"
					aria-label="Filter picks by the title behind them"
				>
					<button
						type="button"
						onclick={() => (seedFilter = null)}
						aria-pressed={seedFilter === null}
						class="flex h-12 flex-none items-center rounded-[2px] border px-4 text-sm font-semibold {seedFilter ===
						null
							? 'border-ink text-ink'
							: 'border-line text-muted hover:border-ink hover:text-ink'}">All picks</button
					>
					{#each railSeeds as seed (seed.id)}
						<button
							type="button"
							onclick={() => (seedFilter = seedFilter === seed.id ? null : seed.id)}
							aria-pressed={seedFilter === seed.id}
							class="flex h-12 max-w-64 flex-none items-center gap-2.5 rounded-[2px] border py-1 pr-3.5 pl-1 text-left {seedFilter ===
							seed.id
								? 'border-ink text-ink'
								: 'border-line text-muted hover:border-ink hover:text-ink'}"
						>
							<span
								class="aspect-2/3 h-full flex-none rounded-[2px]"
								style="background:{seed.cover}"
								aria-hidden="true"
							></span>
							<span class="min-w-0">
								<span class="block truncate text-[13px] font-semibold">{seed.title}</span>
								<span class="block font-mono text-[11px] text-dim"
									>{scoreLabel(seed.score)}{seed.type !== (isAnime ? 'ANIME' : 'MANGA')
										? ` · ${seed.type === 'ANIME' ? 'anime' : 'manga'}`
										: ''}</span
								>
							</span>
						</button>
					{/each}
				</div>
			</div>

			{#if filterSeed}
				<p class="m-0 -mb-2 text-sm text-muted">
					Picks because you rated <a href="/title/{filterSeed.id}" class="font-semibold text-ink"
						>{filterSeed.title}</a
					>
					{scoreLabel(filterSeed.score)}
				</p>
			{/if}

			{#if picks.length}
				<ul
					class="m-0 grid list-none grid-cols-2 gap-x-4 gap-y-7 p-0 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 lg:gap-x-5 xl:grid-cols-7"
					data-testid="for-you-picks"
				>
					{#each picks as pick (pick.title.id)}
						<!-- the button sits at the card's foot, so a row's buttons line up -->
						<li class="flex flex-col gap-2">
							<PosterCard title={pick.title} reason={reasonFor(pick)} />
							{#if pick.studio}
								<a
									href="/studio/{pick.studio.id}"
									class="-mt-1 flex min-h-6 items-center gap-1 truncate text-xs text-muted hover:text-ink"
									title="A studio you rate well"
								>
									<span class="material-symbols-rounded !text-[14px]" aria-hidden="true">movie</span
									>
									From {pick.studio.name}
								</a>
							{/if}
							<button
								type="button"
								onclick={() => notThis(pick)}
								class="mt-auto flex h-9 items-center justify-center gap-1 rounded-[2px] border border-line text-xs font-semibold text-muted hover:text-ink"
								aria-label="Not this: hide {pick.title.title}"
							>
								<span class="material-symbols-rounded !text-[16px]" aria-hidden="true">block</span>
								Not this
							</button>
						</li>
					{/each}
				</ul>
			{:else}
				<p class="m-0 py-12 text-center text-sm text-muted">
					{#if tune.changed && tuned.length === 0 && data.picks.length}
						Tune leaves out every pick. <button
							type="button"
							onclick={() => tune.reset()}
							class="font-semibold text-ink underline-offset-2 hover:underline">Reset it</button
						>
					{:else if data.picks.length}
						No more picks here. Rate more titles to get new ones.
					{:else}
						AniList has no recommendations for your top-rated titles yet.
					{/if}
				</p>
			{/if}
		{/if}
	</div>
</PageShell>
