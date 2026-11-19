<script lang="ts">
	import type { Paragraph } from '#lib/page-data/markdown.ts';

	// A character's or staff member's description, from parseDescription: text
	// only (never HTML). Spoilers are hidden behind a chip until one is clicked,
	// which shows them all; a long bio folds under "Read more".

	interface Props {
		paragraphs: Paragraph[];
	}

	let { paragraphs }: Props = $props();

	let open = $state(false);
	let spoilersShown = $state(false);

	// about seven lines of text
	const long = $derived(
		paragraphs.reduce((n, p) => n + p.reduce((m, s) => m + s.text.length, 0), 0) > 700 ||
			paragraphs.length > 4
	);
	const hasSpoilers = $derived(paragraphs.some((p) => p.some((s) => s.spoiler)));
</script>

{#if paragraphs.length}
	<div class="flex max-w-205 flex-col items-start gap-2">
		<div
			id="bio"
			class="relative flex flex-col gap-3 text-[15px] leading-relaxed text-pretty text-[#C9BFAE] lg:text-base {long &&
			!open
				? 'max-h-[11lh] overflow-hidden mask-b-from-60%'
				: ''}"
		>
			{#each paragraphs as paragraph, i (i)}
				<p class="m-0 whitespace-pre-line">
					{#each paragraph as s, j (j)}
						{#if s.spoiler && !spoilersShown}
							<button
								type="button"
								onclick={() => (spoilersShown = true)}
								class="mx-0.5 inline-flex h-6 items-center rounded-[2px] bg-[rgba(255,138,120,.12)] px-2 align-middle text-xs font-semibold text-[#FF8A78] hover:bg-[rgba(255,138,120,.2)]"
								>Spoiler</button
							>
						{:else if s.href}
							<a
								href={s.href}
								target={s.external ? '_blank' : undefined}
								rel={s.external ? 'noreferrer' : undefined}
								class="font-semibold text-ink underline decoration-white/25 underline-offset-2 hover:decoration-white/60 {s.bold
									? 'font-bold'
									: ''} {s.italic ? 'italic' : ''}"
								>{s.text}{#if s.external}<span class="sr-only"> (opens in a new tab)</span>{/if}</a
							>
						{:else if s.bold || s.italic || s.spoiler}
							<span
								class="{s.bold ? 'font-semibold text-ink' : ''} {s.italic
									? 'italic'
									: ''} {s.spoiler ? 'rounded bg-[rgba(255,138,120,.08)]' : ''}">{s.text}</span
							>
						{:else}{s.text}{/if}
					{/each}
				</p>
			{/each}
		</div>
		<div class="flex gap-4">
			{#if long}
				<button
					type="button"
					onclick={() => (open = !open)}
					aria-expanded={open}
					aria-controls="bio"
					class="flex items-center gap-0.5 text-sm font-semibold text-muted hover:text-ink"
				>
					{open ? 'Show less' : 'Read more'}
					<span class="material-symbols-rounded text-[20px]!" aria-hidden="true"
						>{open ? 'expand_less' : 'expand_more'}</span
					>
				</button>
			{/if}
			{#if hasSpoilers}
				<button
					type="button"
					onclick={() => (spoilersShown = !spoilersShown)}
					aria-pressed={spoilersShown}
					class="text-sm font-semibold text-muted hover:text-ink"
				>
					{spoilersShown ? 'Hide spoilers' : 'Show spoilers'}
				</button>
			{/if}
		</div>
	</div>
{/if}
