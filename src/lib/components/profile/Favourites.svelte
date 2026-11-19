<script lang="ts">
	import { cssUrl } from '#lib/anilist/adapt.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import PosterCard from '#lib/components/shared/PosterCard.svelte';
	import { hasFavourites, type ProfileView } from '#lib/page-data/profile.ts';

	// A profile's favourites, as the staff page lays out its roles: favourite
	// titles (following the Anime / Manga switch) as a grid of posters, then
	// characters and staff, then (anime) studios, each under a section heading.

	interface Props {
		view: ProfileView | null;
		isAnime: boolean;
		/** "your" / "matchai's", for the error messages. */
		whose: string;
		/** The profile failed to load. */
		failed: boolean;
		error?: string;
		retryIn?: string;
		rateLimited?: boolean;
		onRetry: () => void;
	}

	let { view, isAnime, whose, failed, error, retryIn, rateLimited, onRetry }: Props = $props();

	const kind = $derived(isAnime ? 'anime' : 'manga');
	const titles = $derived(view ? (isAnime ? view.anime : view.manga) : []);
	const people = $derived(
		view
			? [
					{ heading: 'Favourite characters', id: 'fav-characters', list: view.characters },
					{ heading: 'Favourite staff', id: 'fav-staff', list: view.staff }
				].filter((g) => g.list.length)
			: []
	);
</script>

{#snippet heading(text: string, id: string)}
	<h2
		{id}
		class="m-0 font-display text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
	>
		{text}
	</h2>
{/snippet}

{#if failed}
	<SectionError
		title="Couldn't load {whose} favourites"
		{onRetry}
		detail={error}
		{retryIn}
		{rateLimited}
	/>
{:else if view && hasFavourites(view)}
	{#if view.titlesError}
		<SectionError
			title="Couldn't load {whose} favourite anime and manga"
			{onRetry}
			detail={view.titlesError}
		/>
	{/if}
	{#if titles.length}
		<section class="flex flex-col gap-4" aria-labelledby="fav-titles">
			{@render heading(`Favourite ${kind}`, 'fav-titles')}
			<div class="grid grid-cols-3 gap-x-3 gap-y-5 sm:grid-cols-4 md:grid-cols-5 xl:grid-cols-6">
				{#each titles as t (t.id)}
					<PosterCard title={t} size="sm" />
				{/each}
			</div>
		</section>
	{:else if !view.titlesError}
		<p class="m-0 text-sm text-muted">No favourite {kind} on AniList yet.</p>
	{/if}

	{#each people as group (group.id)}
		<section class="flex flex-col gap-4" aria-labelledby={group.id}>
			{@render heading(group.heading, group.id)}
			<ul
				class="m-0 grid list-none grid-cols-4 gap-x-3 gap-y-4 p-0 sm:grid-cols-6 md:grid-cols-7 xl:grid-cols-8"
			>
				{#each group.list as p (p.id)}
					<li class="min-w-0">
						<a href={p.href} class="flex flex-col gap-1.5 text-ink hover:text-ink">
							<span
								class="block aspect-3/4 w-full rounded-[2px] bg-raised bg-cover bg-center"
								style={p.image ? `background-image:${cssUrl(p.image)}` : ''}
								aria-hidden="true"
							></span>
							<span class="line-clamp-2 text-[13px] leading-snug font-semibold">{p.name}</span>
						</a>
					</li>
				{/each}
			</ul>
		</section>
	{/each}

	{#if isAnime && view.studios.length}
		<section class="flex flex-col gap-3" aria-labelledby="fav-studios">
			{@render heading('Favourite studios', 'fav-studios')}
			<div class="flex flex-wrap gap-2">
				{#each view.studios as studio (studio.id)}
					<a
						href={studio.href}
						class="flex h-9 items-center btn-quiet px-3.5 text-sm font-semibold text-ink hover:text-ink"
						>{studio.name}</a
					>
				{/each}
			</div>
		</section>
	{/if}
{/if}
