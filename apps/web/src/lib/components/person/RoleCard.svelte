<script lang="ts">
	import { cssUrl } from '#lib/anilist/adapt.ts';
	import type { MediaListStatus } from '#lib/anilist/types.ts';
	import { STATUS_COLOR, statusLabel } from '#lib/catalog/status.ts';
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import type { MediaCard } from '#lib/page-data/person.ts';

	// A title in someone's roles: its cover and name (opening the title), what
	// they did on it, and the people tied to it (the character voiced, or the
	// voice actor), each opening their own page.

	interface Person {
		href: string;
		name: string;
		image: string | null;
		/** "Main", "(young)". */
		caption?: string;
	}

	interface Props {
		media: MediaCard;
		/** Under the title: a credit's roles, or a character's role in it. */
		caption?: string;
		people?: Person[];
		/** The viewer's list status for the title, if it's on their list. */
		status?: MediaListStatus | null;
	}

	let { media, caption, people = [], status = null }: Props = $props();
</script>

<div class="flex min-w-0 flex-col gap-2">
	<a href="/title/{media.id}" class="flex flex-col gap-1.5 text-ink hover:text-ink">
		<div
			class="relative aspect-2/3 overflow-hidden rounded-[2px] transition-transform duration-200 ease-[cubic-bezier(.2,.8,.2,1)] hover:-translate-y-0.5 motion-reduce:transform-none"
			style="background:{media.color}"
		>
			<CoverImage title={{ coverUrl: media.cover ?? undefined }} />
			{#if status}
				<span
					class="absolute top-1.5 left-1.5 flex items-center gap-1.5 rounded-[2px] bg-[rgba(19,17,15,.75)] px-2 py-0.5 text-[11px] font-semibold text-ink backdrop-blur-md"
				>
					<span class="h-1.5 w-1.5 rounded-full" style="background:{STATUS_COLOR[status]}"></span>
					{statusLabel(status, media.isAnime)}
				</span>
			{/if}
		</div>
		<div>
			<div class="line-clamp-2 text-[13px] leading-snug font-semibold">{media.title}</div>
			{#if media.meta}<div class="text-[11px] text-dim">{media.meta}</div>{/if}
		</div>
	</a>
	{#if caption}
		<div class="line-clamp-2 text-[11px] leading-snug text-muted">{caption}</div>
	{/if}
	{#each people as p (p.href)}
		<a href={p.href} class="flex min-w-0 items-center gap-2 text-ink hover:text-ink">
			<span
				class="h-8 w-8 flex-none rounded-full bg-[linear-gradient(135deg,var(--color-raised-hover),var(--color-raised-hover))] bg-cover bg-top"
				style={p.image ? `background-image:${cssUrl(p.image)}` : ''}
				aria-hidden="true"
			></span>
			<span class="min-w-0">
				<span class="line-clamp-2 text-xs leading-tight font-semibold">{p.name}</span>
				{#if p.caption}<span class="block truncate text-[11px] text-dim">{p.caption}</span>{/if}
			</span>
		</a>
	{/each}
</div>
