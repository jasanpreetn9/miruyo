<script module lang="ts">
	import type { Title } from '#lib/catalog/types.ts';

	export interface UpcomingItem {
		id: number;
		title: Title;
		/** The title as shown: a long sequel's shortened in the middle (shortTitle). */
		name: string;
		/** The season it's slated for, or "Date TBA". */
		when: string;
		by: string;
		/** "Premieres in 66d 20h", once AniList has a date. */
		cd: string | null;
	}
</script>

<script lang="ts">
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import SectionHeading from '#lib/components/shared/SectionHeading.svelte';
	import { goto } from '$app/navigation';
	import type { MediaListStatus } from '#lib/anilist/types.ts';
	import { STATUS_COLOR, statusLabel } from '#lib/catalog/status.ts';
	import StatusMenu from '#lib/components/shared/StatusMenu.svelte';
	import { editor } from '#lib/state/editor.svelte.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { changeStatus } from '#lib/state/list-actions.ts';
	import { session } from '#lib/state/session.svelte.ts';

	interface Props {
		heading: string;
		items: UpcomingItem[];
		/** Where "See all →" goes; no link when unset. */
		seeAllHref?: string;
	}

	let { heading, items, seeAllHref }: Props = $props();

	function setStatus(item: UpcomingItem, status: MediaListStatus) {
		if (!list.sync) {
			if (session.authState === 'out') void goto('/login');
			return;
		}
		void changeStatus(item.title, status);
	}
	const plan = (item: UpcomingItem) => setStatus(item, 'PLANNING');
</script>

<!-- "Plan", or the title's status once it's on the list -->
{#snippet planButton(item: UpcomingItem, compact: boolean)}
	{@const entry = list.entryFor(item.title)}
	{#if entry && compact}
		<span
			class="flex h-11 flex-none items-center gap-1 px-1 text-xs font-semibold"
			style="color:{STATUS_COLOR[entry.status]}"
		>
			<span class="material-symbols-rounded !text-[16px]" aria-hidden="true">check</span>
			{statusLabel(entry.status, item.title.isAnime)}
		</span>
	{:else if entry}
		<span
			class="flex h-8 flex-none items-center gap-1 px-1 text-xs font-semibold"
			style="color:{STATUS_COLOR[entry.status]}"
		>
			<span class="material-symbols-rounded !text-[16px]" aria-hidden="true">check</span>
			{statusLabel(entry.status, item.title.isAnime)}
		</span>
		{@render menu(item)}
	{:else if compact}
		<button
			onclick={() => plan(item)}
			class="grid h-11 w-11 flex-none press place-items-center rounded-full border border-line text-ink"
			aria-label="Plan to {item.title.isAnime ? 'watch' : 'read'} {item.title.title}"
		>
			<span class="material-symbols-rounded !text-[20px]">bookmark_add</span>
		</button>
	{:else}
		<button
			onclick={() => plan(item)}
			class="touch-target relative flex h-8 press items-center gap-1 rounded-[2px] border border-line px-2.5 text-xs font-semibold text-ink hover:border-ink"
			aria-label="Plan {item.title.title}"
		>
			<span class="material-symbols-rounded !text-[16px]">add</span>Plan
		</button>
		{@render menu(item)}
	{/if}
{/snippet}

<!-- the chevron: any other list status, or the full editor -->
{#snippet menu(item: UpcomingItem)}
	<StatusMenu
		status={list.entryFor(item.title)?.status ?? null}
		isAnime={item.title.isAnime}
		onSelect={(status) => setStatus(item, status)}
		variant="icon"
		class="h-8 w-8 border border-line"
		label="More list options for {item.title.title}"
		onOpenEditor={session.authState === 'out' ? undefined : () => editor.open(item.title)}
	/>
{/snippet}

<div class="flex flex-col gap-3.5 lg:gap-[18px]">
	<SectionHeading {heading} jp="放送予定" {seeAllHref} />

	<!-- desktop: ruled entries in columns, the cover with an offset shadow in its own colour -->
	<div class="hidden grid-cols-2 gap-x-14 border-t border-line lg:grid xl:grid-cols-3">
		{#each items as item (item.id)}
			<div class="group flex gap-5 border-b border-line py-5">
				<div
					class="relative aspect-2/3 w-[84px] flex-none self-start overflow-hidden transition-shadow duration-(--duration-lift) ease-enter group-hover:shadow-[6px_6px_0_var(--shadow)]"
					style="background:{item.title.placeholder};--shadow:color-mix(in oklch,{item.title
						.accent} 55%,var(--color-canvas))"
				>
					<CoverImage title={item.title} />
				</div>
				<div class="flex min-w-0 flex-1 flex-col gap-1.5">
					<!-- every entry the same: season, title, studio, then the countdown (once dated) and Plan -->
					<div class="text-[11px] font-semibold tracking-[0.12em] text-dim uppercase">
						{item.when}
					</div>
					<a
						href="/title/{item.id}"
						title={item.name === item.title.title ? undefined : item.title.title}
						aria-label={item.name === item.title.title ? undefined : item.title.title}
						class="line-clamp-2 text-[16px] leading-snug font-bold text-ink hover:text-ink hover:underline"
					>
						{item.name}
					</a>
					{#if item.by}<div class="text-[13px]" style="color:{item.title.accent}">
							{item.by}
						</div>{/if}
					<div class="mt-auto flex flex-wrap items-center gap-x-3 gap-y-2 pt-1">
						{#if item.cd}
							<div class="font-mono text-xs whitespace-nowrap text-muted">
								<span class="sr-only">Premieres </span>in {item.title.next?.in}
							</div>
						{/if}
						<!-- Plan and its menu stay together when the row wraps -->
						<div class="flex items-center gap-2">{@render planButton(item, false)}</div>
					</div>
				</div>
			</div>
		{/each}
	</div>

	<!-- tablets: two columns, so a row isn't a short title across the screen -->
	<div class="flex flex-col px-4 md:grid md:grid-cols-2 md:gap-x-6 lg:hidden">
		{#each items as item (item.id)}
			<div class="flex items-center gap-3 border-b border-line py-2">
				<div
					class="relative aspect-2/3 w-11 flex-none overflow-hidden"
					style="background:{item.title.placeholder}"
				>
					<CoverImage title={item.title} />
				</div>
				<div class="flex min-w-0 flex-1 flex-col gap-1">
					<a
						href="/title/{item.id}"
						class="truncate text-sm font-semibold text-ink hover:text-ink hover:underline"
						>{item.title.title}</a
					>
					<!-- the countdown once AniList schedules it; until then, the season -->
					{#if item.cd}
						<div class="font-mono text-[11px] text-blue">{item.cd}</div>
					{:else}
						<div class="text-[11px] text-muted">{item.when}</div>
					{/if}
				</div>
				{@render planButton(item, true)}
			</div>
		{/each}
	</div>
</div>
