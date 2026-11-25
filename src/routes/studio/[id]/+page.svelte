<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { untrack } from 'svelte';
	import {
		fetchStudio,
		fetchStudioMedia,
		toggleFavourite,
		type PersonSort
	} from '#lib/anilist/client.ts';
	import type { StudioMedia, StudioPage } from '#lib/anilist/types.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import RoleCard from '#lib/components/person/RoleCard.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import { createStudioContent } from '#lib/page-data/studio.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { loadListState } from '#lib/state/list-state.ts';
	import { PagedResults, type Page } from '#lib/state/paged.svelte.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';
	import { session } from '#lib/state/session.svelte.ts';
	import { studioSort } from './sort.ts';

	// A studio: what it is, then the titles it made, most popular or newest
	// first (?sort=newest), as the staff page lists someone's credits. Studios
	// have no picture or bio on AniList, so the header is the name alone.

	type Edge = StudioMedia['edges'][number];
	/** The studio, and the sort its first page of titles came in. */
	type Loaded = { studio: StudioPage; sort: PersonSort };

	const id = $derived(Number(page.params.id));
	const sort = $derived(studioSort(page.url.searchParams));
	const signedIn = $derived(session.authState === 'in');

	// the studio loads once; changing the sort only reloads the titles
	const studio = new Resource<Loaded>();
	const titles = new PagedResults<Edge>();

	function load(studioId: number, signed: boolean, by: PersonSort) {
		return studio.load(`${studioId}:${signed}`, async () => ({
			studio: await fetchStudio(studioId, { signedIn: signed, sort: by }),
			sort: by
		}));
	}

	$effect(() => {
		if (session.authState === 'loading' || !Number.isInteger(id) || id <= 0) return;
		void load(
			id,
			signedIn,
			untrack(() => sort)
		);
	});

	$effect(() => () => {
		studio.reset();
		titles.reset();
	});

	const loaded = $derived<Loaded | null>(studio.data?.studio.id === id ? studio.data : null);

	const toPage = (m: StudioMedia): Page<Edge> => ({
		items: m.edges,
		total: m.pageInfo.total,
		hasMore: m.pageInfo.hasNextPage
	});

	// titles: the first page comes with the studio when the sort matches
	$effect(() => {
		const d = loaded;
		if (!d) return;
		const studioId = d.studio.id;
		const by = sort;
		const own = d.sort === by;
		void titles.load(
			`${studioId}:${by}`,
			(p) =>
				p === 1 && own
					? Promise.resolve(toPage(d.studio.media))
					: fetchStudioMedia(studioId, p, by).then(toPage),
			{ onItems: (items) => void loadListState(items.map((e) => e.node.id)) }
		);
	});

	const content = $derived.by(() => {
		if (!loaded) return null;
		const own = titles.items.length && !titles.stale;
		const first = loaded.sort === sort ? loaded.studio.media : null;
		const edges = own ? titles.items : (first?.edges ?? []);
		const hasMore = own ? titles.hasMore : (first?.pageInfo.hasNextPage ?? false);
		return createStudioContent(
			{ ...loaded.studio, media: { pageInfo: { total: null, hasNextPage: hasMore }, edges } },
			{
				titles: signedIn ? 'userPreferred' : 'english',
				adult: signedIn && session.showAdultContent
			}
		);
	});

	const notFound = $derived(
		(!Number.isInteger(id) || id <= 0 || /not found/i.test(studio.error)) && !loaded
	);
	const statusOf = (mediaId: number) =>
		session.authState === 'out' ? null : (list.get(mediaId)?.status ?? null);

	const SORTS: { by: PersonSort; label: string }[] = [
		{ by: 'POPULARITY_DESC', label: 'Popular' },
		{ by: 'START_DATE_DESC', label: 'Newest' }
	];

	function setSort(by: PersonSort) {
		void goto(by === 'START_DATE_DESC' ? '?sort=newest' : page.url.pathname, {
			replace: true,
			reset: false
		});
	}

	// toggled here, by id; otherwise what AniList says
	let toggled = $state<Record<number, boolean>>({});
	const favourite = $derived(toggled[id] ?? loaded?.studio.isFavourite ?? false);
	let favouriteBusy = $state(false);
	async function onFavourite() {
		if (session.authState === 'out') return void goto('/login');
		if (favouriteBusy || !loaded) return;
		favouriteBusy = true;
		const was = favourite;
		toggled[id] = !was;
		try {
			await toggleFavourite('STUDIO', loaded.studio.id);
		} catch (err) {
			console.error('Failed to toggle favourite:', err);
			toggled[id] = was;
		} finally {
			favouriteBusy = false;
		}
	}

	let shareNote = $state('');
	async function share() {
		const url = location.href;
		try {
			if (navigator.share) await navigator.share({ title: content?.name, url });
			else {
				await navigator.clipboard.writeText(url);
				shareNote = 'Link copied';
				setTimeout(() => (shareNote = ''), 2000);
			}
		} catch {
			// cancelled, or no clipboard access
		}
	}

	function back() {
		if (history.length > 1) history.back();
		else void goto('/');
	}
</script>

<svelte:head>
	<title>{content ? `${content.name} · miruyo` : 'miruyo'}</title>
</svelte:head>

<PageShell nav="browse" tab="browse">
	{#if notFound}
		<div class="flex flex-col items-center gap-3 px-6 py-24 text-center">
			<span class="material-symbols-rounded text-[40px]! text-dim" aria-hidden="true"
				>search_off</span
			>
			<h1
				class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				This studio isn't on AniList
			</h1>
			<p class="m-0 text-sm text-muted">It may have been removed or merged.</p>
			<a href="/browse" class="mt-2 font-semibold">Browse titles →</a>
		</div>
	{:else if studio.failed && !loaded}
		<div class="px-4 pt-10 lg:px-10 xl:px-20">
			<SectionError
				title="Couldn't load this studio"
				onRetry={() => load(id, signedIn, sort)}
				detail={studio.error}
				retryIn={studio.retry.active ? studio.retry.label : undefined}
				rateLimited={studio.rateLimited}
			/>
		</div>
	{:else if !content}
		<div class="flex flex-col gap-4 px-4 pt-6 lg:px-10 lg:pt-12 xl:px-20" aria-busy="true">
			<Skeleton class="h-16 w-16 rounded-[2px]" />
			<Skeleton class="h-10 w-1/2" />
			<Skeleton class="h-4 w-1/4" />
		</div>
	{:else}
		{#key id}
			<div class="flex flex-col gap-8 px-4 pt-3 pb-20 lg:px-10 lg:pt-12 xl:px-20">
				<!-- mobile: back and share, as on the title and staff pages -->
				<div class="flex justify-between lg:hidden">
					<button
						type="button"
						onclick={back}
						aria-label="Back"
						class="grid h-11 w-11 place-items-center rounded-full bg-raised text-ink"
					>
						<span class="material-symbols-rounded text-[22px]!" aria-hidden="true">arrow_back</span>
					</button>
					<button
						type="button"
						onclick={share}
						aria-label="Share"
						class="grid h-11 w-11 place-items-center rounded-full bg-raised text-ink"
					>
						<span class="material-symbols-rounded text-[22px]!" aria-hidden="true">ios_share</span>
					</button>
				</div>

				<header class="flex flex-col gap-5" data-testid="studio-header">
					<div class="flex items-center gap-4">
						<div
							class="grid h-16 w-16 flex-none place-items-center rounded-[2px] border border-line bg-[linear-gradient(160deg,var(--color-raised-hover),var(--color-raised))] lg:h-20 lg:w-20"
							aria-hidden="true"
						>
							<span class="material-symbols-rounded text-[32px]! text-muted lg:text-[40px]!"
								>{content.kind === 'Animation studio' ? 'movie' : 'domain'}</span
							>
						</div>
						<div class="flex min-w-0 flex-col gap-1">
							<h1
								class="m-0 font-display text-[56px] leading-[0.92] font-light tracking-[-0.045em] text-balance"
							>
								{content.name}
							</h1>
							<div class="text-sm text-muted lg:text-base">{content.kind}</div>
						</div>
					</div>
					<div class="flex flex-wrap items-center gap-3">
						<button
							type="button"
							onclick={onFavourite}
							aria-pressed={favourite}
							class="flex h-11 press items-center justify-center gap-2 btn-quiet px-4 text-sm font-semibold"
							style="color:{favourite ? 'var(--color-pink)' : 'var(--color-ink)'}"
						>
							<span
								class="material-symbols-rounded text-[20px]!"
								style="font-variation-settings:'FILL' {favourite ? 1 : 0}"
								aria-hidden="true">favorite</span
							>
							{favourite ? 'Favourite' : 'Add to favourites'}
							<span class="font-mono text-xs font-normal text-dim">{content.favourites}</span>
						</button>
						<button
							type="button"
							onclick={share}
							class="hidden h-11 press items-center gap-2 btn-quiet px-4 text-sm font-semibold text-ink lg:flex"
						>
							<span class="material-symbols-rounded text-[20px]!" aria-hidden="true">ios_share</span
							>
							Share
						</button>
						<a
							href={content.anilistHref}
							target="_blank"
							rel="noreferrer"
							class="flex h-11 items-center gap-1 px-1 text-sm font-semibold text-muted hover:text-ink"
						>
							View on AniList
							<span class="material-symbols-rounded text-[16px]!" aria-hidden="true"
								>open_in_new</span
							>
						</a>
					</div>
				</header>

				<section
					class="flex flex-col gap-4"
					aria-labelledby="titles-heading"
					data-testid="studio-titles"
				>
					<div class="flex flex-wrap items-center gap-3">
						<h2
							id="titles-heading"
							class="m-0 flex-1 font-display text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
						>
							Titles
						</h2>
						<div
							class="flex rounded-[2px] border border-line bg-raised p-0.5"
							role="group"
							aria-label="Sort titles"
						>
							{#each SORTS as option (option.by)}
								<button
									type="button"
									onclick={() => setSort(option.by)}
									aria-pressed={sort === option.by}
									class="h-9 rounded-[2px] px-3 text-[13px] font-semibold {sort === option.by
										? 'bg-[var(--color-raised-hover)] text-ink'
										: 'text-muted hover:text-ink'}"
								>
									{option.label}
								</button>
							{/each}
						</div>
					</div>
					{#if content.titles.length}
						<div
							class="grid grid-cols-3 gap-x-3 gap-y-5 transition-opacity sm:grid-cols-4 md:grid-cols-5 xl:grid-cols-7 {titles.stale
								? 'opacity-50'
								: ''}"
							aria-busy={titles.stale}
						>
							{#each content.titles as t (t.key)}
								<RoleCard
									media={t.media}
									caption={t.caption ?? undefined}
									status={statusOf(t.media.id)}
								/>
							{/each}
						</div>
					{:else if !titles.loading}
						<p class="m-0 text-sm text-muted">No titles listed on AniList yet.</p>
					{/if}
					{#if titles.error && !titles.loading && titles.items.length}
						<SectionError
							title="Couldn't load more titles"
							onRetry={() => titles.retryNow()}
							detail={titles.error}
							retryIn={titles.retry.active ? titles.retry.label : undefined}
							rateLimited={titles.rateLimited}
						/>
					{:else if content.hasMore}
						<button
							type="button"
							onclick={() => titles.loadMore()}
							disabled={titles.loadingMore}
							class="flex h-11 press items-center justify-center self-center btn-quiet px-5 text-sm font-semibold text-ink disabled:opacity-60"
						>
							{titles.loadingMore ? 'Loading…' : 'Load more'}
						</button>
					{/if}
				</section>
			</div>
		{/key}
	{/if}
</PageShell>

{#if shareNote}
	<div class="fixed inset-x-0 bottom-28 z-50 flex justify-center lg:bottom-8" role="status">
		<div class="rounded-[2px] bg-ink px-4 py-2 text-sm font-semibold text-surface">
			{shareNote}
		</div>
	</div>
{/if}
