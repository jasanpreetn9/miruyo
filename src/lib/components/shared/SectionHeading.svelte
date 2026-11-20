<script lang="ts">
	import type { Snippet } from 'svelte';
	import { reveal } from '#lib/motion.ts';

	// A section's heading, editorial style: a serif title, an
	// optional Japanese gloss and note, then a hairline out to "See all".

	interface Props {
		heading: string;
		/** Set in italics after the heading ("Because you loved *Frieren*"). */
		em?: string;
		level?: 'h2' | 'h3';
		/** A small Japanese gloss beside the title (視聴中). */
		jp?: string;
		/** A quiet note after the title ("3 new episodes"). */
		subtitle?: string;
		subtitleColor?: string;
		subtitleTestId?: string;
		/** Where "See all →" goes; no link when unset. */
		seeAllHref?: string;
		/** The link's text, when it isn't "See all →". */
		seeAllText?: string;
		/** Replaces the link (e.g. a toggle). */
		end?: Snippet;
		class?: string;
	}

	let {
		heading,
		em,
		level = 'h3',
		jp,
		subtitle,
		subtitleColor = 'var(--color-dim)',
		subtitleTestId,
		seeAllHref,
		seeAllText = 'See all →',
		end,
		class: className = 'px-4 lg:px-0'
	}: Props = $props();
</script>

<div class="flex items-baseline gap-2.5 lg:gap-3.5 {className}">
	<svelte:element
		this={level}
		class="m-0 font-display text-[22px] leading-tight font-medium tracking-[-0.02em] text-ink lg:text-[30px]"
	>
		{heading}{#if em}{' '}<em class="font-medium italic">{em}</em>{/if}
	</svelte:element>
	{#if jp}
		<span class="hidden font-jp text-[13px] text-dim sm:inline" lang="ja">{jp}</span>
	{/if}
	{#if subtitle}
		<span
			class="min-w-0 truncate text-[13px] font-medium"
			style="color:{subtitleColor}"
			data-testid={subtitleTestId}>{subtitle}</span
		>
	{/if}
	<span class="draw h-px min-w-4 flex-1 self-center bg-line" aria-hidden="true" {@attach reveal}
	></span>
	{#if end}
		{@render end()}
	{:else if seeAllHref}
		<a
			href={seeAllHref}
			class="touch-target relative flex-none text-sm font-medium text-muted hover:text-ink"
			aria-label="See all: {heading}{em ? ` ${em}` : ''}">{seeAllText}</a
		>
	{/if}
</div>
