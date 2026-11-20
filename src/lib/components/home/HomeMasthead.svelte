<script lang="ts">
	import { newEpisodesFor } from '#lib/catalog/progress.ts';
	import type { ContinueContent } from '#lib/page-data/home.ts';
	import { clock } from '#lib/state/clock.svelte.ts';

	// Home's masthead: a dateline, a greeting,
	// and where you stand in one sentence, with three running totals beside it.
	// Signed in only, so it's never server-rendered (the time of day would
	// differ between server and browser).

	interface Props {
		content: ContinueContent | null;
		isAnime: boolean;
		/** "Fall 2026", for the dateline. */
		season: string;
	}

	let { content, isAnime, season }: Props = $props();

	const JP_DAYS = ['日', '月', '火', '水', '木', '金', '土'];

	const now = $derived(new Date(clock.seconds * 1000));
	const dateline = $derived(
		now.toLocaleDateString('en-GB', {
			weekday: 'long',
			day: 'numeric',
			month: 'long',
			year: 'numeric'
		})
	);
	const greeting = $derived.by(() => {
		const h = now.getHours();
		if (h < 5) return ['Up', 'late'];
		if (h < 12) return ['Good', 'morning'];
		if (h < 18) return ['Good', 'afternoon'];
		return ['Good', 'evening'];
	});

	const items = $derived(content?.continueItems ?? []);
	const behind = $derived(
		items.map((i) => newEpisodesFor(i.title, i.progress) ?? 0).filter((n) => n > 0)
	);
	const newCount = $derived(behind.reduce((a, n) => a + n, 0));
	/** On your list and airing before midnight tonight. */
	const airingToday = $derived.by(() => {
		const midnight = new Date(now);
		midnight.setHours(24, 0, 0, 0);
		const end = midnight.getTime() / 1000;
		return items.filter((i) => {
			const at = i.title.next?.at;
			return !!at && at > clock.seconds && at < end;
		}).length;
	});
	const unit = $derived(isAnime ? 'episode' : 'chapter');
	const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`;
</script>

<header class="px-4 lg:px-10 xl:px-20">
	<div
		class="flex rise justify-between border-b border-line py-3 text-[11px] tracking-[0.1em] text-dim uppercase lg:text-xs"
	>
		<span
			>{dateline} ·
			<span class="font-jp tracking-normal" lang="ja">{JP_DAYS[now.getDay()]}曜日</span></span
		>
		<span class="hidden sm:inline">{season}</span>
	</div>

	<div
		class="flex flex-col gap-6 border-b-[3px] border-double border-line py-7 lg:flex-row lg:items-end lg:justify-between lg:gap-10 lg:py-10"
	>
		<div class="min-w-0">
			<h1
				class="m-0 rise font-display text-[44px] leading-[0.95] font-light tracking-[-0.045em] [--d:70ms] lg:text-[80px]"
			>
				{greeting[0]} <em class="font-medium italic">{greeting[1]}</em>.
			</h1>
			{#if content}
				<p
					class="m-0 mt-3 max-w-[54ch] rise text-[15px] leading-relaxed text-muted [--d:140ms] lg:mt-4 lg:text-[17px]"
				>
					{#if newCount}
						You're <b class="font-semibold text-ink">{plural(newCount, unit)} behind</b>
						across {plural(behind.length, isAnime ? 'show' : 'series')}.
					{:else if items.length}
						You're <b class="font-semibold text-ink">caught up</b> on everything you're {isAnime
							? 'watching'
							: 'reading'}.
					{:else}
						Nothing in progress right now.
					{/if}
					{#if isAnime && airingToday}
						<b class="font-semibold text-ink">{airingToday}</b> of yours
						{airingToday === 1 ? 'airs' : 'air'} later today.
					{/if}
				</p>
			{/if}
		</div>

		{#if content}
			<dl
				class="m-0 flex flex-none rise gap-8 [--d:200ms] lg:gap-10 lg:text-right"
				data-testid="home-tally"
			>
				<div class="flex flex-col-reverse">
					<dt class="text-[11px] tracking-[0.1em] text-dim uppercase">
						To {isAnime ? 'watch' : 'read'}
					</dt>
					<dd
						class="m-0 mb-1.5 font-display text-[40px] leading-none font-light tracking-[-0.04em] lg:text-[56px]"
						style="color:{newCount
							? isAnime
								? 'var(--color-anime)'
								: 'var(--color-manga)'
							: 'var(--color-ink)'}"
					>
						{newCount}
					</dd>
				</div>
				<div class="flex flex-col-reverse">
					<dt class="text-[11px] tracking-[0.1em] text-dim uppercase">
						{isAnime ? 'Watching' : 'Reading'}
					</dt>
					<dd
						class="m-0 mb-1.5 font-display text-[40px] leading-none font-light tracking-[-0.04em] lg:text-[56px]"
					>
						{items.length}
					</dd>
				</div>
				{#if isAnime}
					<div class="flex flex-col-reverse">
						<dt class="text-[11px] tracking-[0.1em] text-dim uppercase">Airing today</dt>
						<dd
							class="m-0 mb-1.5 font-display text-[40px] leading-none font-light tracking-[-0.04em] lg:text-[56px]"
						>
							{airingToday}
						</dd>
					</div>
				{/if}
			</dl>
		{/if}
	</div>
</header>
