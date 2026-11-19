<script lang="ts">
	import { cssUrl } from '#lib/anilist/adapt.ts';
	import { fetchSearchPeople } from '#lib/anilist/client.ts';
	import {
		buildPeopleResults,
		hasPeople,
		type PersonResult
	} from '#lib/page-data/search-people.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';
	import type { SearchPeopleResponse } from '#lib/anilist/types.ts';

	// Among Browse's titles while searching, after the first rows: the
	// characters, staff, users and studios the search also matches, a row each.
	// Nothing shows until there's a match, and a failure just leaves the
	// titles (it's extra, not the search).

	interface Props {
		q: string;
		isAnime: boolean;
		titles: 'userPreferred' | 'english';
	}

	let { q, isAnime, titles }: Props = $props();

	const people = new Resource<SearchPeopleResponse>();
	$effect(() => {
		const search = q.trim();
		if (search) void people.load(search.toLowerCase(), () => fetchSearchPeople(search));
	});
	$effect(() => () => people.reset());

	const results = $derived(
		people.data && q.trim() ? buildPeopleResults(people.data, { isAnime, titles }) : null
	);
</script>

{#snippet row(heading: string, list: PersonResult[])}
	{#if list.length}
		<section class="flex flex-col gap-2.5" aria-label={heading}>
			<h2 class="m-0 text-[11px] font-semibold tracking-wider text-dim uppercase">{heading}</h2>
			<ul
				class="-mx-4 my-0 flex scrollbar-none list-none gap-3 overflow-x-auto px-4 lg:mx-0 lg:px-0"
			>
				{#each list as p (p.id)}
					<li class="w-[84px] flex-none lg:w-24">
						<a href={p.href} class="flex flex-col gap-1.5 text-ink hover:text-ink">
							<span
								class="block aspect-3/4 w-full rounded-[2px] bg-raised bg-cover bg-center"
								style={p.image ? `background-image:${cssUrl(p.image)}` : ''}
								aria-hidden="true"
							></span>
							<span class="line-clamp-2 text-[13px] leading-snug font-semibold">{p.name}</span>
							{#if p.sub}
								<span class="-mt-1 truncate text-[11px] text-dim">{p.sub}</span>
							{/if}
						</a>
					</li>
				{/each}
			</ul>
		</section>
	{/if}
{/snippet}

{#if results && hasPeople(results)}
	<div class="flex flex-col gap-5 border-y border-line py-6" data-testid="search-people">
		{@render row('Characters', results.characters)}
		{@render row('Staff', results.staff)}
		{#if results.users.length}
			<section class="flex flex-col gap-2.5" aria-label="Users">
				<h2 class="m-0 text-[11px] font-semibold tracking-wider text-dim uppercase">Users</h2>
				<ul
					class="-mx-4 my-0 flex scrollbar-none list-none gap-3 overflow-x-auto px-4 lg:mx-0 lg:px-0"
				>
					{#each results.users as u (u.id)}
						<li class="w-[72px] flex-none lg:w-20">
							<a href={u.href} class="flex flex-col items-center gap-1.5 text-ink hover:text-ink">
								<span
									class="block aspect-square w-14 rounded-full bg-raised bg-cover bg-center lg:w-16"
									style={u.image ? `background-image:${cssUrl(u.image)}` : ''}
									aria-hidden="true"
								></span>
								<span class="w-full truncate text-center text-[13px] font-semibold">{u.name}</span>
							</a>
						</li>
					{/each}
				</ul>
			</section>
		{/if}
		{#if results.studios.length}
			<section class="flex flex-col gap-2.5" aria-label="Studios">
				<h2 class="m-0 text-[11px] font-semibold tracking-wider text-dim uppercase">Studios</h2>
				<div class="flex flex-wrap gap-2">
					{#each results.studios as s (s.id)}
						<a
							href={s.href}
							class="flex h-9 items-center gap-1.5 btn-quiet px-3.5 text-sm font-semibold text-ink hover:text-ink"
						>
							{s.name}
						</a>
					{/each}
				</div>
			</section>
		{/if}
	</div>
{/if}
