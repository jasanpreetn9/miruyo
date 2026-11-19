<script lang="ts">
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import type { Title } from '#lib/catalog/types.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { toast } from '#lib/state/toast.svelte.ts';
	import { session } from '#lib/state/session.svelte.ts';

	interface Props {
		/** Popular titles to pick from (Home's trending row). */
		titles?: Title[];
		/** Hide this card for good (per user and mode). */
		onSkip: () => void;
		/** The picks were saved — Home reloads the list. */
		onAdded: () => void;
	}

	let { titles = [], onSkip, onAdded }: Props = $props();

	let picked = $state<Record<number, boolean>>({});
	let saving = $state(false);
	let error = $state('');

	const isAnime = $derived(session.mode === 'anime');
	const accent = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');
	const accentInk = $derived(isAnime ? 'var(--color-anime-ink)' : 'var(--color-manga-ink)');
	const accentSoft = $derived(isAnime ? 'var(--color-anime-soft)' : 'var(--color-manga-soft)');
	const pickedIds = $derived(titles.filter((t) => picked[t.id]).map((t) => t.id));
	const firstName = $derived(session.user?.name ?? '');

	function toggle(id: number) {
		picked[id] = !picked[id];
	}

	async function addPicks() {
		if (!pickedIds.length || saving) return;
		saving = true;
		error = '';
		// "Tap anything you've seen" — so they go on the list as Completed
		const results = await Promise.all(pickedIds.map((id) => list.setStatus(id, 'COMPLETED', null)));
		saving = false;
		const failed = results.filter((ok) => !ok).length;
		if (failed) {
			error = `Couldn't add ${failed} of them — AniList didn't respond. Try again.`;
			return;
		}
		const n = pickedIds.length;
		toast.show({ message: `Added ${n} ${n === 1 ? 'title' : 'titles'} to Completed` });
		onAdded();
	}
</script>

<div class="mx-auto flex max-w-2xl flex-col gap-3.5 p-4 lg:p-5 lg:pt-10">
	<div
		class="flex flex-col gap-3.5 border-y-[3px] border-double border-line py-6"
		data-testid="quick-pick"
	>
		<div class="text-[11px] font-semibold tracking-wider uppercase" style="color:{accentSoft}">
			Welcome{firstName ? `, ${firstName}` : ''}
		</div>
		<h2 class="m-0 font-display text-[30px] leading-[1.05] font-medium tracking-[-0.025em]">
			Your {isAnime ? 'anime' : 'manga'} list is empty. Let's fix that in 30 seconds.
		</h2>
		<p class="m-0 text-sm leading-relaxed text-muted">
			Tap anything you've {isAnime ? 'seen' : 'read'}. We'll use it to build your Continue row and
			For You picks.
		</p>

		{#if titles.length}
			<div class="grid grid-cols-3 gap-2 md:grid-cols-6">
				{#each titles as title (title.id)}
					{@const on = !!picked[title.id]}
					<button
						type="button"
						onclick={() => toggle(title.id)}
						aria-pressed={on}
						aria-label={title.title}
						class="relative aspect-2/3 press overflow-hidden text-left"
						style="background:{title.placeholder};box-shadow:{on
							? `0 0 0 2px var(--color-surface),0 0 0 4px ${accent}`
							: 'none'}"
					>
						<CoverImage {title} />
						<span
							class="absolute inset-0"
							style="background:linear-gradient(0deg,rgba(19,17,15,.9),transparent 55%)"
						></span>
						<span
							class="absolute right-1.5 bottom-1.5 left-1.5 text-[11px] leading-tight font-semibold text-ink"
						>
							{title.short}
						</span>
						<span
							class="absolute top-1.5 right-1.5 grid h-6 w-6 place-items-center rounded-full"
							style="background:{on ? accent : 'rgba(19,17,15,.6)'};color:{accentInk}"
							aria-hidden="true"
						>
							<span class="material-symbols-rounded !text-[16px]" style="opacity:{on ? 1 : 0}"
								>check</span
							>
						</span>
					</button>
				{/each}
			</div>

			<button
				onclick={addPicks}
				disabled={!pickedIds.length || saving}
				class="h-12 press rounded-[2px] text-[15px] font-semibold disabled:opacity-60"
				style="background:{accent};color:{accentInk}"
			>
				{saving
					? 'Adding…'
					: pickedIds.length
						? `Add ${pickedIds.length} to Completed`
						: 'Pick at least one'}
			</button>
			{#if error}
				<p class="m-0 text-sm text-[#FF8FA8]" role="alert">{error}</p>
			{/if}
		{:else}
			<a
				href="/browse"
				class="flex h-12 items-center justify-center rounded-[2px] text-[15px] font-semibold"
				style="background:{accent};color:{accentInk}"
			>
				Browse titles
			</a>
		{/if}

		<div class="text-center text-[13px] text-muted">
			or
			<a href="https://anilist.co/settings/import" target="_blank" rel="noreferrer"
				>import from AniList</a
			>
			·
			<button
				type="button"
				onclick={onSkip}
				class="touch-target relative font-semibold text-muted hover:text-ink">skip</button
			>
		</div>
	</div>
</div>
