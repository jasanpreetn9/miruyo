<script lang="ts">
	import { statusLabel } from '#lib/catalog/status.ts';
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import type { HeroPick } from '#lib/page-data/home.ts';
	import { editor } from '#lib/state/editor.svelte.ts';
	import { changeStatus } from '#lib/state/list-actions.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { session } from '#lib/state/session.svelte.ts';

	// One of the hero's slides: something to watch next and why ("Because you
	// rated Cowboy Bebop 9.5/10"). Plan adds it; once it's on your list the
	// button says where and opens the editor. Tracking is Continue's, above.
	// Editorial: the cover with an offset shadow in its own
	// colour, over a halftone (and the banner, washed out) in that colour.

	interface Props {
		slide: HeroPick;
		/** "Not this" (For You picks only): hides it here and on For You. */
		onDismiss?: () => void;
		/** The carousel lists the other picks at the right (desktop): leave room. */
		listed?: boolean;
	}

	let { slide, onDismiss, listed = false }: Props = $props();

	const title = $derived(slide.title);
	const isAnime = $derived(title.isAnime);
	/** The cover's colour, mixed toward the page for fills and shadows. */
	const shade = $derived(`color-mix(in oklch, ${slide.title.accent} 50%, var(--color-canvas))`);
	const entry = $derived(session.authState === 'out' ? null : list.entryFor(title));
	const count = $derived(
		isAnime
			? title.eps
				? `${title.eps} ${title.eps === 1 ? 'episode' : 'episodes'}`
				: 'Airing'
			: title.total
				? `${title.total} ch`
				: 'Ongoing'
	);
	const meta = $derived([title.format, count, title.studio ?? title.author].filter(Boolean));

	function plan() {
		if (session.authState === 'out') location.href = '/login';
		else void changeStatus(title, 'PLANNING');
	}
</script>

{#snippet star()}
	<span
		class="material-symbols-rounded !text-[16px]"
		style="color:var(--color-gold);font-variation-settings:'FILL' 1"
		aria-hidden="true">star</span
	>
{/snippet}

<!-- the main action: Plan, or where it is once it's on your list -->
{#snippet primary(cls: string, testid?: string)}
	{#if entry}
		<button
			type="button"
			onclick={() => editor.open(title)}
			class="flex press items-center justify-center gap-2 rounded-[2px] border border-line font-semibold text-ink hover:border-ink {cls}"
		>
			<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">check</span>
			{statusLabel(entry.status, isAnime)}
		</button>
	{:else}
		<button
			type="button"
			onclick={plan}
			data-testid={testid}
			class="flex press items-center justify-center gap-2 rounded-[2px] bg-ink font-semibold text-canvas transition-colors hover:bg-muted {cls}"
		>
			<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">bookmark_add</span>
			Plan to {isAnime ? 'watch' : 'read'}
		</button>
	{/if}
{/snippet}

{#snippet dismiss(cls: string, wide = false)}
	{#if onDismiss}
		<button
			type="button"
			onclick={onDismiss}
			aria-label="Not this: hide {title.title}"
			title="Not this"
			class="flex press items-center justify-center gap-2 rounded-[2px] border border-line font-semibold text-muted hover:border-ink hover:text-ink {cls}"
		>
			{#if wide}Not for me{:else}<span
					class="material-symbols-rounded !text-[20px]"
					aria-hidden="true">block</span
				>{/if}
		</button>
	{/if}
{/snippet}

<!-- desktop: the cover with its offset shadow, then the reason, title and
     actions; behind them a halftone in the cover's colour (and the banner,
     washed out, where there is one), fading out to the right -->
<div class="relative isolate hidden px-10 pt-[18px] pb-10 lg:block xl:px-20">
	<div
		class="absolute inset-0 -z-10 [mask:radial-gradient(ellipse_62%_58%_at_25%_50%,#000_10%,transparent_100%)]"
	>
		{#if title.banner}
			<div
				class="absolute inset-0 opacity-25 mix-blend-luminosity grayscale"
				style="background:{title.banner}"
				data-testid="hero-banner"
			></div>
		{/if}
		<div
			class="absolute inset-0"
			style="background:radial-gradient(circle at 1px 1px, color-mix(in oklch, {title.color} 45%, transparent) 1px, transparent 1.6px) 0 0 / 7px 7px, linear-gradient(90deg, color-mix(in oklch, {title.color} 20%, var(--color-canvas)), var(--color-canvas) 75%)"
			data-testid={title.banner ? undefined : 'hero-banner-fallback'}
		></div>
	</div>

	<div
		class="grid grid-cols-[220px_minmax(0,1fr)] items-center gap-14 xl:gap-16 {listed
			? 'pr-[330px] xl:pr-[380px]'
			: ''}"
	>
		<a
			href="/title/{title.id}"
			class="relative aspect-2/3 w-[220px] rise"
			aria-label="More about {title.title}"
		>
			<span
				class="absolute inset-0 overflow-hidden"
				style="background:{title.placeholder};box-shadow:12px 12px 0 {shade}"
			>
				<CoverImage {title} eager />
			</span>
		</a>

		<div class="flex max-w-[680px] min-w-0 rise flex-col [--d:90ms]">
			<div
				class="text-[12px] font-semibold tracking-[0.14em] uppercase"
				style="color:{title.accent}"
				data-testid="hero-reason"
			>
				{slide.reason}
			</div>
			<h2
				class="m-0 mt-3 line-clamp-2 font-display text-[52px] leading-[0.98] font-semibold tracking-[-0.035em] text-balance text-ink"
			>
				<a href="/title/{title.id}" class="text-ink hover:text-ink">{title.title}</a>
			</h2>
			<!-- clamped so long synopses don't push the actions down; the full text is on the title page -->
			<p
				class="m-0 mt-5 line-clamp-3 max-w-[600px] text-[15px] leading-relaxed text-pretty text-muted"
				data-testid="hero-synopsis"
			>
				{title.synopsis ?? ''}
			</p>
			<dl class="m-0 mt-6 flex flex-wrap gap-x-9 gap-y-3 border-t border-line pt-4">
				{#if title.score > 0}
					<div>
						<dt class="text-[11px] tracking-[0.1em] text-dim uppercase">Score</dt>
						<dd class="m-0 mt-1 font-mono text-[15px] tabular-nums">{title.score}</dd>
					</div>
				{/if}
				{#each meta as m, i (i)}
					<div>
						<dt class="text-[11px] tracking-[0.1em] text-dim uppercase">
							{i === 0 ? 'Format' : i === 1 ? 'Length' : isAnime ? 'Studio' : 'Author'}
						</dt>
						<dd class="m-0 mt-1 font-mono text-[15px]">{m}</dd>
					</div>
				{/each}
				{#if title.next}
					<div>
						<dt class="text-[11px] tracking-[0.1em] text-dim uppercase">Next</dt>
						<dd class="m-0 mt-1 font-mono text-[15px] tabular-nums">
							{title.unit}
							{title.next.ep} in {title.next.in}
						</dd>
					</div>
				{/if}
			</dl>
			<div class="mt-7 flex items-center gap-2.5">
				{@render primary('h-11 px-5 text-[14px]', 'hero-plan')}
				<a
					href="/title/{title.id}"
					class="flex h-11 press items-center gap-2 rounded-[2px] border border-line px-4 text-[14px] font-semibold text-ink hover:border-ink hover:text-ink"
				>
					More info
				</a>
				{@render dismiss('h-11 px-4 text-[14px]', true)}
			</div>
		</div>
	</div>
</div>

<!-- touch: a landscape card, cover beside the text -->
<div class="px-4 lg:hidden">
	<div class="relative overflow-hidden border-y border-line">
		<div
			class="absolute inset-0 [mask:linear-gradient(90deg,#000,transparent_85%)]"
			style="background:radial-gradient(circle at 1px 1px, color-mix(in oklch, {title.color} 45%, transparent) 1px, transparent 1.6px) 0 0 / 6px 6px"
		></div>
		<div class="relative flex gap-4 py-4 pr-1">
			<a
				href="/title/{title.id}"
				class="relative h-36 w-24 flex-none overflow-hidden md:h-48 md:w-32"
				style="background:{title.placeholder};box-shadow:6px 6px 0 {shade}"
				aria-label="More about {title.title}"
			>
				<CoverImage {title} eager />
			</a>
			<div class="flex min-w-0 flex-1 flex-col">
				<div
					class="line-clamp-2 text-[11px] font-semibold tracking-[0.1em] uppercase"
					style="color:{title.accent}"
				>
					{slide.reason}
				</div>
				<a
					href="/title/{title.id}"
					class="mt-1.5 line-clamp-2 font-display text-[24px] leading-[1.05] font-semibold tracking-[-0.02em] text-ink hover:text-ink"
				>
					{title.title}
				</a>
				<div class="mt-1 flex items-center gap-1 truncate text-[13px] text-muted">
					{#if title.score > 0}
						{@render star()}
						<span class="font-mono font-semibold">{title.score}</span> ·
					{/if}
					{meta.slice(0, 2).join(' · ')}
				</div>
				<div class="flex-1"></div>
				<div class="mt-3 flex items-center gap-2">
					{@render primary('h-11 min-w-0 flex-1 px-3 text-[15px] md:flex-none md:px-5')}
					{@render dismiss('h-11 w-11 flex-none')}
				</div>
			</div>
		</div>
	</div>
</div>
