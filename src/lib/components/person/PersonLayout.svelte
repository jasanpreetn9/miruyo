<script lang="ts">
	import { goto } from '$app/navigation';
	import type { Snippet } from 'svelte';
	import { cssUrl } from '#lib/anilist/adapt.ts';
	import type { PersonHeader } from '#lib/page-data/person.ts';
	import Bio from './Bio.svelte';

	// The top of a staff, character or user page, in the title page's layout:
	// the portrait and facts in a sticky column on desktop (beside the name on
	// phones), then the name, other names and bio, then the page's own
	// sections (`children`).

	interface Props {
		person: PersonHeader;
		favourite?: boolean;
		onFavourite?: () => void;
		/** In place of Add to favourites (a user page: Follow, or Settings). */
		actions?: Snippet;
		/** A banner for the top of the page (a user's); else the portrait, blurred. */
		banner?: string | null;
		/** A square portrait (an avatar) rather than 3:4. */
		square?: boolean;
		/** The facts under the bio on phones too (a user page has its Stats instead). */
		phoneFacts?: boolean;
		children: Snippet;
	}

	let {
		person,
		favourite = false,
		onFavourite,
		actions,
		banner = null,
		square = false,
		phoneFacts = true,
		children
	}: Props = $props();
	const shape = $derived(square ? 'aspect-square' : 'aspect-3/4');

	let spoilerNamesShown = $state(false);

	let shareNote = $state('');
	async function share() {
		const url = location.href;
		try {
			if (navigator.share) await navigator.share({ title: person.name, url });
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

{#snippet portrait(classes: string)}
	<div
		class="{classes} bg-[linear-gradient(160deg,var(--color-raised-hover),var(--color-raised))] bg-cover bg-top"
		style={person.image ? `background-image:${cssUrl(person.image)}` : ''}
		role="img"
		aria-label={person.name}
	></div>
{/snippet}

{#snippet favouriteButton()}
	{#if actions}
		{@render actions()}
	{:else}
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
			<span class="font-mono text-xs font-normal text-dim">{person.favourites}</span>
		</button>
	{/if}
{/snippet}

{#snippet facts()}
	{#if person.facts.length}
		<dl class="m-0 flex flex-col border-t border-ink">
			{#each person.facts as row, i (i)}
				<div class="flex justify-between gap-4 border-b border-line py-2.5 text-[13px]">
					<dt class="flex-none pt-px text-[11px] tracking-[0.1em] text-dim uppercase">
						{row.label}
					</dt>
					<dd class="m-0 text-right font-mono text-[12.5px] text-ink">{row.value}</dd>
				</div>
			{/each}
		</dl>
	{/if}
{/snippet}

<!-- the banner, or the portrait blurred, behind the top of the page -->
<div class="relative h-40 overflow-hidden lg:h-56">
	{#if banner}
		<div
			class="absolute inset-0 bg-cover bg-center opacity-70"
			style="background-image:{cssUrl(banner)}"
		></div>
	{:else if person.image}
		<div
			class="absolute -inset-16 bg-cover bg-center opacity-60"
			style="background-image:{cssUrl(person.image)};filter:blur(40px) saturate(1.2)"
		></div>
	{/if}
	<div
		class="absolute inset-0"
		style="background:linear-gradient(0deg,#13110F 0%,rgba(19,17,15,.55) 55%,rgba(19,17,15,.25) 100%)"
	></div>
	<!-- mobile: back and share over the band -->
	<div class="absolute inset-x-3 top-3 flex justify-between lg:hidden">
		<button
			type="button"
			onclick={back}
			aria-label="Back"
			class="grid h-11 w-11 place-items-center rounded-full bg-[rgba(19,17,15,.6)] text-ink backdrop-blur-md"
		>
			<span class="material-symbols-rounded text-[22px]!" aria-hidden="true">arrow_back</span>
		</button>
		<button
			type="button"
			onclick={share}
			aria-label="Share"
			class="grid h-11 w-11 place-items-center rounded-full bg-[rgba(19,17,15,.6)] text-ink backdrop-blur-md"
		>
			<span class="material-symbols-rounded text-[22px]!" aria-hidden="true">ios_share</span>
		</button>
	</div>
</div>

<div
	class="relative -mt-20 grid gap-6 px-4 pb-20 lg:-mt-40 lg:grid-cols-[240px_minmax(0,1fr)] lg:gap-12 lg:px-10 xl:px-20"
>
	<aside class="hidden lg:block">
		<div class="sticky top-20 flex flex-col gap-4">
			{@render portrait(`${shape} w-full rounded-[2px] shadow-[0_20px_50px_rgba(0,0,0,.45)]`)}
			{@render favouriteButton()}
			{@render facts()}
			<a
				href={person.anilistHref}
				target="_blank"
				rel="noreferrer"
				class="flex items-center gap-1 text-sm font-semibold text-muted hover:text-ink"
			>
				View on AniList
				<span class="material-symbols-rounded text-[16px]!" aria-hidden="true">open_in_new</span>
			</a>
		</div>
	</aside>

	<div class="flex min-w-0 flex-col gap-6 lg:pt-32">
		<!-- headline (mobile: next to a smaller portrait) -->
		<div class="flex items-end gap-3.5 lg:block">
			{@render portrait(`${shape} w-28 flex-none rounded-[2px] lg:hidden`)}
			<div class="flex min-w-0 flex-col gap-1.5 pb-1 lg:gap-2.5 lg:pb-0">
				<h1
					class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] text-balance lg:text-[44px]"
				>
					{person.name}
				</h1>
				{#if person.native}
					<div class="text-[13px] text-muted lg:text-base">{person.native}</div>
				{/if}
			</div>
		</div>

		{#if person.altNames.length || person.spoilerNames.length}
			<div class="flex flex-col gap-1 text-[13px] text-muted">
				{#if person.altNames.length}
					<div>
						<span class="text-dim">Also known as</span>
						{#each person.altNames as name, i (name)}{#if i}{' · '}{/if}<bdi>{name}</bdi>{/each}
					</div>
				{/if}
				{#if person.spoilerNames.length}
					{#if spoilerNamesShown}
						<div class="text-[#FF8A78]">
							<span class="text-dim">Spoiler names</span>
							{#each person.spoilerNames as name, i (name)}{#if i}{' · '}{/if}<bdi>{name}</bdi
								>{/each}
						</div>
					{:else}
						<button
							type="button"
							onclick={() => (spoilerNamesShown = true)}
							class="self-start text-sm font-semibold text-muted hover:text-ink"
						>
							Show {person.spoilerNames.length} spoiler {person.spoilerNames.length === 1
								? 'name'
								: 'names'}
						</button>
					{/if}
				{/if}
			</div>
		{/if}

		<div class="flex flex-col lg:hidden">{@render favouriteButton()}</div>

		<Bio paragraphs={person.bio} />

		<!-- on phones the facts sit under the bio, as the desktop column keeps them in view -->
		<div class="flex-col gap-3 lg:hidden {phoneFacts ? 'flex' : 'hidden'}">
			{@render facts()}
			<a
				href={person.anilistHref}
				target="_blank"
				rel="noreferrer"
				class="flex items-center gap-1 text-sm font-semibold text-muted hover:text-ink"
			>
				View on AniList
				<span class="material-symbols-rounded text-[16px]!" aria-hidden="true">open_in_new</span>
			</a>
		</div>

		{@render children()}
	</div>
</div>

{#if shareNote}
	<div class="fixed inset-x-0 bottom-28 z-50 flex justify-center lg:bottom-8" role="status">
		<div class="rounded-[2px] bg-ink px-4 py-2 text-sm font-semibold text-surface">
			{shareNote}
		</div>
	</div>
{/if}
