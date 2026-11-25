<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import {
		fetchCharacter,
		fetchCharacterAppearances,
		toggleFavourite
	} from '#lib/anilist/client.ts';
	import type { CharacterAppearances, CharacterPerson } from '#lib/anilist/types.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import PersonLayout from '#lib/components/person/PersonLayout.svelte';
	import RoleCard from '#lib/components/person/RoleCard.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import { createCharacterContent } from '#lib/page-data/person.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { loadListState } from '#lib/state/list-state.ts';
	import { PagedResults } from '#lib/state/paged.svelte.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';
	import { session } from '#lib/state/session.svelte.ts';
	import type { PageProps } from './$types';

	// A character (the title page's layout): who they are, then every title
	// they're in with who voices them, one language at a time.

	let { data }: PageProps = $props();

	type Edge = CharacterAppearances['edges'][number];

	const id = $derived(Number(page.params.id));
	const signedIn = $derived(session.authState === 'in');

	const character = new Resource<CharacterPerson>();
	const appearances = new PagedResults<Edge>();

	function load(characterId: number, signed: boolean) {
		return character.load(`${characterId}:${signed}`, () =>
			fetchCharacter(characterId, { signedIn: signed })
		);
	}

	$effect(() => {
		if (session.authState === 'loading' || !Number.isInteger(id) || id <= 0) return;
		void load(id, signedIn);
	});

	$effect(() => () => {
		character.reset();
		appearances.reset();
	});

	// the server's signed-out copy (first load only) shows until the browser's own arrives
	const loaded = $derived(
		character.data?.id === id ? character.data : data.character?.id === id ? data.character : null
	);

	// the first page of appearances comes with the character
	$effect(() => {
		const c = loaded;
		if (!c) return;
		void appearances.load(
			String(c.id),
			async (p) => {
				const media = p === 1 ? c.media : await fetchCharacterAppearances(c.id, p);
				return {
					items: media.edges,
					total: media.pageInfo.total,
					hasMore: media.pageInfo.hasNextPage
				};
			},
			{ onItems: (items) => void loadListState(items.map((e) => e.node.id)) }
		);
	});

	const content = $derived.by(() => {
		if (!loaded) return null;
		const own = appearances.items.length && !appearances.stale;
		return createCharacterContent(
			own
				? {
						...loaded,
						media: {
							pageInfo: { total: null, hasNextPage: appearances.hasMore },
							edges: appearances.items
						}
					}
				: loaded,
			{
				titles: signedIn ? 'userPreferred' : 'english',
				adult: signedIn && session.showAdultContent
			}
		);
	});

	// the voices shown: Japanese (the original) unless another is picked; a
	// pick carries over to the next character when they have it too
	let picked = $state<string | null>(null);
	const language = $derived(
		picked && content?.languages.includes(picked) ? picked : (content?.languages[0] ?? null)
	);

	const notFound = $derived(
		(!Number.isInteger(id) || id <= 0 || /not found/i.test(character.error)) && !loaded
	);
	const statusOf = (mediaId: number) =>
		session.authState === 'out' ? null : (list.get(mediaId)?.status ?? null);

	// toggled here, by id; otherwise what AniList says
	let toggled = $state<Record<number, boolean>>({});
	const favourite = $derived(toggled[id] ?? loaded?.isFavourite ?? false);
	let favouriteBusy = $state(false);
	async function onFavourite() {
		if (session.authState === 'out') return void goto('/login');
		if (favouriteBusy || !loaded) return;
		favouriteBusy = true;
		const was = favourite;
		toggled[id] = !was;
		try {
			await toggleFavourite('CHARACTER', loaded.id);
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

<PageShell nav="browse" tab="browse">
	{#if notFound}
		<div class="flex flex-col items-center gap-3 px-6 py-24 text-center">
			<span class="material-symbols-rounded text-[40px]! text-dim" aria-hidden="true"
				>search_off</span
			>
			<h1
				class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				This character isn't on AniList
			</h1>
			<p class="m-0 text-sm text-muted">They may have been removed or merged.</p>
			<a href="/browse" class="mt-2 font-semibold">Browse titles →</a>
		</div>
	{:else if character.failed && !loaded}
		<div class="px-4 pt-10 lg:px-10 xl:px-20">
			<SectionError
				title="Couldn't load this character"
				onRetry={() => load(id, signedIn)}
				detail={character.error}
				retryIn={character.retry.active ? character.retry.label : undefined}
				rateLimited={character.rateLimited}
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
				{#if content.appearances.length}
					<section
						class="flex flex-col gap-4"
						aria-labelledby="appearances-heading"
						data-testid="appearances"
					>
						<div class="flex flex-wrap items-center gap-3">
							<h2
								id="appearances-heading"
								class="m-0 flex-1 font-display text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
							>
								Appears in
							</h2>
							{#if content.languages.length > 1}
								<label class="flex items-center gap-2 text-[13px] text-muted">
									Voices
									<select
										bind:value={() => language, (v) => (picked = v)}
										class="h-9 btn-quiet px-3 text-[13px] font-semibold text-ink"
									>
										{#each content.languages as l (l)}
											<option value={l}>{l}</option>
										{/each}
									</select>
								</label>
							{/if}
						</div>
						<div
							class="grid grid-cols-3 gap-x-3 gap-y-5 sm:grid-cols-4 md:grid-cols-5 xl:grid-cols-6"
						>
							{#each content.appearances as a (a.key)}
								<RoleCard
									media={a.media}
									caption={a.role}
									status={statusOf(a.media.id)}
									people={a.voices
										.filter((v) => v.language === language)
										.map((v) => ({
											href: `/staff/${v.id}`,
											name: v.name,
											image: v.image,
											caption: v.note ?? undefined
										}))}
								/>
							{/each}
						</div>
						{#if appearances.error && !appearances.loading && appearances.items.length}
							<SectionError
								title="Couldn't load more titles"
								onRetry={() => appearances.retryNow()}
								detail={appearances.error}
								retryIn={appearances.retry.active ? appearances.retry.label : undefined}
								rateLimited={appearances.rateLimited}
							/>
						{:else if content.hasMore}
							<button
								type="button"
								onclick={() => appearances.loadMore()}
								disabled={appearances.loadingMore}
								class="flex h-11 press items-center justify-center self-center btn-quiet px-5 text-sm font-semibold text-ink disabled:opacity-60"
							>
								{appearances.loadingMore ? 'Loading…' : 'Load more'}
							</button>
						{/if}
					</section>
				{:else}
					<p class="m-0 text-sm text-muted">No titles listed on AniList yet.</p>
				{/if}
			</PersonLayout>
		{/key}
	{/if}
</PageShell>
