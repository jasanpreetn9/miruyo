<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { untrack } from 'svelte';
	import {
		fetchStaff,
		fetchStaffCredits,
		fetchStaffVoiceRoles,
		toggleFavourite,
		type PersonSort
	} from '#lib/anilist/client.ts';
	import type { StaffCredits, StaffPerson, StaffVoiceRoles } from '#lib/anilist/types.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import PersonLayout from '#lib/components/person/PersonLayout.svelte';
	import RoleCard from '#lib/components/person/RoleCard.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import { createStaffContent } from '#lib/page-data/person.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { loadListState } from '#lib/state/list-state.ts';
	import { PagedResults, type Page } from '#lib/state/paged.svelte.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';
	import { session } from '#lib/state/session.svelte.ts';
	import { staffSort } from './sort.ts';
	import type { PageProps } from './$types';

	// A staff member (design: the title page's layout): who they are, then their
	// voice roles and credits, most popular or newest first (?sort=newest).
	// "What else has this voice actor done" is the point of the page.

	let { data }: PageProps = $props();

	type VoiceEdge = StaffVoiceRoles['edges'][number];
	type CreditEdge = StaffCredits['edges'][number];
	/** The person, and the sort their first page of roles came in. */
	type Loaded = { person: StaffPerson; sort: PersonSort };

	const id = $derived(Number(page.params.id));
	const sort = $derived(staffSort(page.url.searchParams));
	const signedIn = $derived(session.authState === 'in');

	// the person loads once; changing the sort only reloads the roles
	const staff = new Resource<Loaded>();
	const voice = new PagedResults<VoiceEdge>();
	const credits = new PagedResults<CreditEdge>();

	function load(staffId: number, signed: boolean, by: PersonSort) {
		return staff.load(`${staffId}:${signed}`, async () => ({
			person: await fetchStaff(staffId, { signedIn: signed, sort: by }),
			sort: by
		}));
	}

	$effect(() => {
		if (session.authState === 'loading' || !Number.isInteger(id) || id <= 0) return;
		// the sort only picks the first page that comes with the person: a new sort reloads the roles alone
		void load(
			id,
			signedIn,
			untrack(() => sort)
		);
	});

	$effect(() => () => {
		staff.reset();
		voice.reset();
		credits.reset();
	});

	// the server's signed-out copy (first load only) shows until the browser's own arrives
	const loaded = $derived<Loaded | null>(
		staff.data?.person.id === id
			? staff.data
			: data.staff?.id === id
				? { person: data.staff, sort: data.sort }
				: null
	);

	const toPage = <E,>(c: {
		pageInfo: { total: number | null; hasNextPage: boolean };
		edges: E[];
	}): Page<E> => ({
		items: c.edges,
		total: c.pageInfo.total,
		hasMore: c.pageInfo.hasNextPage
	});
	const showListState = (ids: number[]) => void loadListState(ids);

	// roles: the first page comes with the person when the sort matches
	$effect(() => {
		const d = loaded;
		if (!d) return;
		const staffId = d.person.id;
		const by = sort;
		const own = d.sort === by;
		void voice.load(
			`${staffId}:${by}`,
			(p) =>
				p === 1 && own
					? Promise.resolve(toPage(d.person.characterMedia))
					: fetchStaffVoiceRoles(staffId, p, by).then(toPage),
			{ onItems: (items) => showListState(items.map((e) => e.node.id)) }
		);
		void credits.load(
			`${staffId}:${by}`,
			(p) =>
				p === 1 && own
					? Promise.resolve(toPage(d.person.staffMedia))
					: fetchStaffCredits(staffId, p, by).then(toPage),
			{ onItems: (items) => showListState(items.map((e) => e.node.id)) }
		);
	});

	/** What the "Load more" row reads from a section's pages. */
	type MoreState = Pick<
		PagedResults<unknown>,
		| 'items'
		| 'error'
		| 'loading'
		| 'loadingMore'
		| 'rateLimited'
		| 'retry'
		| 'retryNow'
		| 'loadMore'
	>;

	/** What a section shows: its loaded pages, or the first page that came with the person. */
	function shown<E>(
		paged: PagedResults<E>,
		first: { pageInfo: { hasNextPage: boolean }; edges: E[] } | undefined
	): { edges: E[]; hasMore: boolean } {
		if (paged.items.length && !paged.stale) return { edges: paged.items, hasMore: paged.hasMore };
		if (first && loaded?.sort === sort)
			return { edges: first.edges, hasMore: first.pageInfo.hasNextPage };
		return { edges: [], hasMore: false };
	}

	const content = $derived.by(() => {
		if (!loaded) return null;
		const v = shown(voice, loaded.person.characterMedia);
		const c = shown(credits, loaded.person.staffMedia);
		return createStaffContent(
			{
				...loaded.person,
				characterMedia: { pageInfo: { total: null, hasNextPage: v.hasMore }, edges: v.edges },
				staffMedia: { pageInfo: { total: null, hasNextPage: c.hasMore }, edges: c.edges }
			},
			{
				titles: signedIn ? 'userPreferred' : 'english',
				adult: signedIn && session.showAdultContent
			}
		);
	});

	const notFound = $derived(
		(!Number.isInteger(id) || id <= 0 || /not found/i.test(staff.error)) && !loaded
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
	const favourite = $derived(toggled[id] ?? loaded?.person.isFavourite ?? false);
	let favouriteBusy = $state(false);
	async function onFavourite() {
		if (session.authState === 'out') return void goto('/login');
		if (favouriteBusy || !loaded) return;
		favouriteBusy = true;
		const was = favourite;
		toggled[id] = !was;
		try {
			await toggleFavourite('STAFF', loaded.person.id);
		} catch (err) {
			console.error('Failed to toggle favourite:', err);
			toggled[id] = was;
		} finally {
			favouriteBusy = false;
		}
	}
</script>

<svelte:head>
	<title>{content ? `${content.name} · miruyo` : 'miruyo'}</title>
</svelte:head>

{#snippet sortControl()}
	<div
		class="flex rounded-[2px] border border-line bg-raised p-0.5"
		role="group"
		aria-label="Sort roles"
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
{/snippet}

{#snippet more(paged: MoreState, hasMore: boolean, label: string)}
	{#if paged.error && !paged.loading && paged.items.length}
		<SectionError
			title="Couldn't load more {label}"
			onRetry={() => paged.retryNow()}
			detail={paged.error}
			retryIn={paged.retry.active ? paged.retry.label : undefined}
			rateLimited={paged.rateLimited}
		/>
	{:else if hasMore}
		<button
			type="button"
			onclick={() => paged.loadMore()}
			disabled={paged.loadingMore}
			class="flex h-11 press items-center justify-center self-center btn-quiet px-5 text-sm font-semibold text-ink disabled:opacity-60"
		>
			{paged.loadingMore ? 'Loading…' : 'Load more'}
		</button>
	{/if}
{/snippet}

{#snippet voiceSection()}
	{#if content && content.voiceRoles.length}
		<section class="flex flex-col gap-4" aria-labelledby="voice-heading" data-testid="voice-roles">
			<div class="flex flex-wrap items-center gap-3">
				<h2
					id="voice-heading"
					class="m-0 flex-1 font-display text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
				>
					Voice roles
				</h2>
				{@render sortControl()}
			</div>
			<div
				class="grid grid-cols-3 gap-x-3 gap-y-5 transition-opacity sm:grid-cols-4 md:grid-cols-5 xl:grid-cols-6 {voice.stale
					? 'opacity-50'
					: ''}"
				aria-busy={voice.stale}
			>
				{#each content.voiceRoles as r (r.key)}
					<RoleCard
						media={r.media}
						status={statusOf(r.media.id)}
						people={[
							{
								href: `/character/${r.character.id}`,
								name: r.character.name,
								image: r.character.image,
								caption: r.role
							}
						]}
					/>
				{/each}
			</div>
			{@render more(voice, content.voiceHasMore, 'roles')}
		</section>
	{/if}
{/snippet}

{#snippet creditSection()}
	{#if content && content.credits.length}
		<section class="flex flex-col gap-4" aria-labelledby="credits-heading" data-testid="credits">
			<div class="flex flex-wrap items-center gap-3">
				<h2
					id="credits-heading"
					class="m-0 flex-1 font-display text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
				>
					{content.voiceRoles.length ? 'Staff credits' : 'Works'}
				</h2>
				{#if !content.voiceFirst}{@render sortControl()}{/if}
			</div>
			<div
				class="grid grid-cols-3 gap-x-3 gap-y-5 transition-opacity sm:grid-cols-4 md:grid-cols-5 xl:grid-cols-6 {credits.stale
					? 'opacity-50'
					: ''}"
				aria-busy={credits.stale}
			>
				{#each content.credits as c (c.key)}
					<RoleCard media={c.media} caption={c.roles} status={statusOf(c.media.id)} />
				{/each}
			</div>
			{@render more(credits, content.creditsHasMore, 'credits')}
		</section>
	{/if}
{/snippet}

<PageShell nav="browse" tab="browse">
	{#if notFound}
		<div class="flex flex-col items-center gap-3 px-6 py-24 text-center">
			<span class="material-symbols-rounded text-[40px]! text-dim" aria-hidden="true"
				>search_off</span
			>
			<h1
				class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				This person isn't on AniList
			</h1>
			<p class="m-0 text-sm text-muted">They may have been removed or merged.</p>
			<a href="/browse" class="mt-2 font-semibold">Browse titles →</a>
		</div>
	{:else if staff.failed && !loaded}
		<div class="px-4 pt-10 lg:px-10 xl:px-20">
			<SectionError
				title="Couldn't load this person"
				onRetry={() => load(id, signedIn, sort)}
				detail={staff.error}
				retryIn={staff.retry.active ? staff.retry.label : undefined}
				rateLimited={staff.rateLimited}
			/>
		</div>
	{:else if !content}
		<div class="flex flex-col gap-6" aria-busy="true" aria-label="Loading">
			<div class="skeleton-shimmer h-40 lg:h-56"></div>
			<div class="flex flex-col gap-4 px-4 lg:-mt-24 lg:flex-row lg:gap-12 lg:px-10 xl:px-20">
				<Skeleton class="aspect-3/4 w-28 rounded-[2px] lg:w-60" />
				<div class="flex flex-1 flex-col gap-3 lg:pt-24">
					<Skeleton class="h-10 w-2/3" />
					<Skeleton class="h-4 w-1/3" />
				</div>
			</div>
		</div>
	{:else}
		{#key id}
			<PersonLayout person={content} {favourite} {onFavourite}>
				{#if content.voiceFirst}
					{@render voiceSection()}
					{@render creditSection()}
				{:else}
					{@render creditSection()}
					{@render voiceSection()}
				{/if}
				{#if !content.voiceRoles.length && !content.credits.length && !voice.loading && !credits.loading}
					<p class="m-0 text-sm text-muted">No roles listed on AniList yet.</p>
				{/if}
			</PersonLayout>
		{/key}
	{/if}
</PageShell>
