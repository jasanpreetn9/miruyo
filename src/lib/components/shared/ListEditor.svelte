<script lang="ts">
	import { untrack } from 'svelte';
	import { fetchEntry } from '#lib/anilist/client.ts';
	import { formatScore, scoreScale } from '#lib/anilist/score.ts';
	import type { AniListSavedEntry, MediaListStatus } from '#lib/anilist/types.ts';
	import { LIST_STATUSES, STATUS_COLOR, statusLabel } from '#lib/catalog/status.ts';
	import {
		changes,
		customListNames,
		draftFrom,
		fieldEdited,
		isDirty,
		offersCompletion,
		todayInput,
		withProgress,
		withCustomList,
		withStatus,
		withVolumes,
		type EntryDraft
	} from '#lib/editor/draft.ts';
	import { editor, type EditorTarget } from '#lib/state/editor.svelte.ts';
	import { entryFromTitle, list, type ListEntry } from '#lib/state/list.svelte.ts';
	import { confirmSaved, removeFromList } from '#lib/state/list-actions.ts';
	import { session } from '#lib/state/session.svelte.ts';

	// The list editor: a side panel on desktop, a bottom sheet on
	// mobile. Edits are a draft until Save; closing with unsaved edits asks once.

	let dialog = $state<HTMLDialogElement>();
	const target = $derived(editor.target);
	const title = $derived(target?.title);
	const isAnime = $derived(title?.isAnime ?? true);
	const totals = $derived({ total: title?.total ?? null, volumes: title?.vol ?? null });
	const unit = $derived(isAnime ? 'EP' : 'CH');

	let entry = $state<AniListSavedEntry | null>(null);
	let initial = $state<EntryDraft>(draftFrom(null));
	let draft = $state<EntryDraft>(draftFrom(null));
	let loading = $state(false);
	let loadError = $state('');
	let saving = $state(false);
	let saved = $state(false);
	let error = $state('');
	let confirmDiscard = $state(false);
	let confirmDelete = $state(false);
	/** Mobile only: the collapsed rows below the fold. */
	let expanded = $state({ dates: false, repeat: false, notes: false });

	const dirty = $derived(isDirty(initial, draft));
	/** Not on the list yet: saving adds it. */
	const isNew = $derived(!entry && !(title && list.entryFor(title)));
	const completion = $derived(offersCompletion(draft, totals));
	const scale = $derived(scoreScale(session.scoreFormat));
	/** Your custom lists for this title's type (empty ones too), in your order. */
	const customLists = $derived(customListNames(session.customLists(isAnime), entry));
	/**
	 * Whether the lists it's on are known: a new title is on none; one on the
	 * list waits for its full entry. Until then the chips can't be toggled, as
	 * the set sent would leave out the lists it's already on.
	 */
	const listsKnown = $derived(isNew || (!loading && !loadError && entry !== null));

	// open and close the native dialog with the shared editor state
	$effect(() => {
		const t = editor.target;
		if (!dialog) return;
		if (t) {
			untrack(() => start(t));
			if (!dialog.open) dialog.showModal();
		} else if (dialog.open) {
			dialog.close();
		}
	});

	async function start(t: EditorTarget) {
		saving = saved = confirmDiscard = confirmDelete = false;
		autoCompleted = null;
		error = loadError = '';
		expanded = { dates: false, repeat: false, notes: false };
		const local = list.entryFor(t.title);
		if (t.entry !== undefined) return setEntry(t.entry, local);
		// opened from a card: fetch the full entry (score, dates, notes…)
		setEntry(null, local);
		const userId = session.user?.id;
		if (!userId || !local) return;
		loading = true;
		try {
			const full = await fetchEntry(userId, t.title.id);
			if (editor.target === t) mergeEntry(full, local);
		} catch (err) {
			if (editor.target === t) {
				loadError = "Couldn't load the rest of this entry. Saving only changes what you edit.";
			}
			console.error('Failed to load list entry:', err);
		} finally {
			if (editor.target === t) loading = false;
		}
	}

	function setEntry(full: AniListSavedEntry | null, local: ListEntry | null) {
		entry = full;
		initial = draftFrom(full, local ?? undefined);
		draft = { ...initial };
	}

	/**
	 * The full entry arrived while the editor was already open: take its
	 * values only for fields not edited yet, so nothing typed is overwritten.
	 */
	function mergeEntry(full: AniListSavedEntry | null, local: ListEntry | null) {
		const loaded = draftFrom(full, local ?? undefined);
		const merged = { ...loaded };
		for (const key of Object.keys(loaded) as (keyof EntryDraft)[]) {
			if (fieldEdited(key, draft, initial)) (merged as Record<string, unknown>)[key] = draft[key];
		}
		entry = full;
		initial = loaded;
		draft = merged;
	}

	function requestClose() {
		if (saving) return;
		if (dirty && !confirmDiscard) {
			confirmDiscard = true;
			return;
		}
		editor.close();
	}

	function setStatus(status: MediaListStatus) {
		draft = withStatus(draft, status, totals);
		autoCompleted = null;
		saved = false;
	}

	/**
	 * Reaching the last episode/chapter moves the draft to Completed, as +1
	 * does everywhere else, with an inline Undo instead of a toast.
	 */
	let autoCompleted = $state<Pick<EntryDraft, 'status' | 'completedAt'> | null>(null);

	function setProgress(n: number) {
		const next = withProgress(draft, n, totals);
		if (n > draft.progress && offersCompletion(next, totals)) {
			autoCompleted = { status: draft.status, completedAt: draft.completedAt };
			edit(withStatus(next, 'COMPLETED', totals));
		} else {
			edit(next);
		}
	}

	function undoAutoComplete() {
		if (!autoCompleted) return;
		edit({ ...draft, ...autoCompleted });
		autoCompleted = null;
	}

	function edit(next: EntryDraft) {
		draft = next;
		saved = false;
		confirmDiscard = false;
	}

	async function save() {
		if (!title || saving) return;
		if (!dirty && !isNew) return editor.close();
		const patch = changes(initial, draft);
		// adding a title as-is still needs a status to save
		if (isNew && !patch.status) patch.status = draft.status;
		saving = true;
		error = '';
		const base = list.get(title.id) ?? entryFromTitle(title);
		// Undo puts its custom lists back too, when they were known
		const previous = isNew
			? null
			: base
				? { ...base, ...(listsKnown && { onCustomLists: initial.customLists }) }
				: null;
		const ok = await list.update(title.id, patch, base);
		saving = false;
		if (!ok) {
			error = "Couldn't save to AniList. Your changes are still here — try again.";
			return;
		}
		saved = true;
		confirmDiscard = false;
		if (patch.customLists) list.customListsVersion++;
		initial = { ...draft };
		confirmSaved(title, previous, draft.status);
		entry ??= null;
	}

	async function remove() {
		if (!title) return;
		saving = true;
		error = '';
		const local = list.get(title.id);
		const base: ListEntry | null = entry
			? { ...(local ?? entryFromTitle(title)!), id: entry.id, mediaId: title.id }
			: (local ?? null);
		const ok = await removeFromList(title, base);
		saving = false;
		if (!ok) {
			confirmDelete = false;
			error = "Couldn't remove it from AniList. Try again.";
			return;
		}
		editor.close();
	}

	// ── Score: the control follows the viewer's AniList scoring format ──
	const scoreCells = $derived(
		scale.max <= 10 ? Array.from({ length: scale.max }, (_, i) => i + 1) : []
	);
	const halfPoints = $derived(session.scoreFormat === 'POINT_10_DECIMAL');
	const SMILEYS = ['☹', '😐', '☺'];

	function pickScore(n: number) {
		// 10-point decimal: a second click on the same cell takes off half a point
		const next = draft.score === n ? (halfPoints ? n - 0.5 : 0) : n;
		edit({ ...draft, score: next });
	}

	function cellFill(n: number): string {
		const s = draft.score;
		if (n <= Math.floor(s)) return 'var(--color-gold)';
		if (n === Math.ceil(s) && s % 1)
			return 'linear-gradient(90deg,var(--color-gold) 50%,var(--color-raised-hover) 50%)';
		return 'var(--color-raised-hover)';
	}

	// ── Mobile sheet: drag the handle down to close ──
	let dragStart: number | null = null;
	let dragOffset = $state(0);

	function onHandleDown(e: PointerEvent) {
		dragStart = e.clientY;
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
	}

	function onHandleMove(e: PointerEvent) {
		if (dragStart !== null) dragOffset = Math.max(0, e.clientY - dragStart);
	}

	function onHandleUp() {
		if (dragStart === null) return;
		const far = dragOffset > 100;
		dragStart = null;
		dragOffset = 0;
		if (far) requestClose();
	}

	const meta = $derived(
		title ? [title.format, title.countLabel, title.status].filter(Boolean).join(' · ') : ''
	);
</script>

{#snippet stepper(
	label: string,
	value: number,
	of: string,
	onChange: (n: number) => void,
	step: string
)}
	<div class="flex items-center gap-2">
		<button
			type="button"
			onclick={() => onChange(value - 1)}
			disabled={value <= 0}
			aria-label="One less {label}"
			class="grid h-11 w-11 flex-none press place-items-center btn-quiet text-ink disabled:opacity-40"
		>
			<span class="material-symbols-rounded !text-[22px]" aria-hidden="true">remove</span>
		</button>
		<label
			class="flex h-11 min-w-0 flex-1 items-center justify-center gap-1 rounded-[2px] bg-canvas font-mono text-sm"
		>
			<span class="sr-only">{label}</span>
			<input
				type="number"
				min="0"
				{value}
				onchange={(e) => onChange(Number(e.currentTarget.value))}
				class="w-16 border-0 bg-transparent p-0 text-right font-mono text-base text-ink focus:ring-0"
			/>
			<span class="text-dim">/ {of}</span>
		</label>
		<button
			type="button"
			onclick={() => onChange(value + 1)}
			aria-label="One more {label}"
			class="flex h-11 flex-none press items-center gap-1 btn-quiet rounded-[2px] px-3.5 font-mono text-sm font-bold"
		>
			<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">add</span>1 {step}
		</button>
	</div>
{/snippet}

{#snippet sectionLabel(text: string, id?: string)}
	<div class="text-[11px] font-semibold tracking-wider text-dim uppercase" {id}>{text}</div>
{/snippet}

<dialog
	bind:this={dialog}
	class="m-0 h-full max-h-none w-full max-w-none bg-transparent p-0 text-ink backdrop:bg-[rgba(19,17,15,.55)]"
	aria-labelledby="editor-title"
	oncancel={(e) => {
		e.preventDefault();
		requestClose();
	}}
	onclick={(e) => e.target === dialog && requestClose()}
>
	{#if title}
		<div
			class="absolute inset-x-0 bottom-0 flex max-h-[92vh] sheet-in flex-col rounded-t-[6px] border-t border-line bg-raised-hover shadow-[0_-24px_64px_rgba(0,0,0,.6)] lg:inset-y-0 lg:right-0 lg:left-auto lg:max-h-none lg:w-[440px] lg:rounded-none lg:border-t-0 lg:border-l lg:shadow-[-24px_0_64px_rgba(0,0,0,.5)]"
			style="transform:translateY({dragOffset}px)"
			data-testid="list-editor"
		>
			<!-- mobile drag handle -->
			<div
				class="flex touch-none justify-center pt-2.5 pb-1 lg:hidden"
				onpointerdown={onHandleDown}
				onpointermove={onHandleMove}
				onpointerup={onHandleUp}
				onpointercancel={onHandleUp}
				aria-hidden="true"
			>
				<div class="h-[5px] w-10 rounded-full bg-white/20"></div>
			</div>

			<header class="flex items-center gap-3 border-b border-line px-5 pt-2 pb-4 lg:pt-5">
				<div
					class="aspect-2/3 w-11 flex-none rounded-[2px]"
					style="background:{title.thumb ?? title.cover}"
				></div>
				<div class="flex min-w-0 flex-1 flex-col gap-0.5">
					<h2
						id="editor-title"
						class="m-0 truncate font-display text-lg font-medium tracking-[-0.01em]"
					>
						{title.title}
					</h2>
					<div class="truncate text-xs text-muted">{meta}</div>
				</div>
				<button
					type="button"
					onclick={requestClose}
					aria-label="Close editor"
					class="grid h-10 w-10 flex-none place-items-center rounded-[2px] text-muted hover:bg-white/5 hover:text-ink"
				>
					<span class="material-symbols-rounded !text-[22px]" aria-hidden="true">close</span>
				</button>
			</header>

			<div class="flex flex-1 flex-col gap-6 overflow-y-auto px-5 py-5" aria-busy={loading}>
				{#if loadError}
					<p class="m-0 rounded-[2px] bg-[rgba(245,184,61,.1)] px-3 py-2 text-xs text-[#F5D08A]">
						{loadError}
					</p>
				{/if}

				<!-- 1. Status -->
				<section class="flex flex-col gap-2.5">
					{@render sectionLabel('Status', 'editor-status')}
					<div class="grid grid-cols-3 gap-1.5" role="radiogroup" aria-labelledby="editor-status">
						{#each LIST_STATUSES as s (s)}
							{@const on = draft.status === s}
							<button
								type="button"
								role="radio"
								aria-checked={on}
								onclick={() => setStatus(s)}
								class="flex h-10 press items-center justify-center gap-1.5 rounded-[2px] border text-[13px] font-semibold"
								style="background:{on
									? STATUS_COLOR[s] + '22'
									: 'var(--color-canvas)'};border-color:{on
									? STATUS_COLOR[s] + '88'
									: 'rgba(255,255,255,.08)'};color:{on ? 'var(--color-ink)' : 'var(--color-muted)'}"
							>
								<span
									class="h-2 w-2 rounded-full"
									style="background:{STATUS_COLOR[s]}"
									aria-hidden="true"
								></span>
								{statusLabel(s, isAnime)}
							</button>
						{/each}
					</div>
				</section>

				<!-- 2. Progress -->
				<section class="flex flex-col gap-2.5">
					{@render sectionLabel(isAnime ? 'Episode progress' : 'Chapters')}
					{@render stepper(
						isAnime ? 'episode' : 'chapter',
						draft.progress,
						totals.total ? String(totals.total) : '?',
						setProgress,
						unit
					)}
					{#if !totals.total && !isAnime}
						<div class="text-xs text-dim">Ongoing — no chapter total yet</div>
					{/if}
					{#if autoCompleted && draft.status === 'COMPLETED'}
						<div
							class="flex items-center gap-2.5 rounded-[2px] border px-3 py-2"
							style="background:rgba(78,217,138,.1);border-color:rgba(78,217,138,.3)"
							role="status"
						>
							<span class="material-symbols-rounded !text-[20px] text-green" aria-hidden="true"
								>task_alt</span
							>
							<div class="flex-1 text-[13px]">
								Last {isAnime ? 'episode' : 'chapter'} — moved to Completed.
							</div>
							<button
								type="button"
								onclick={undoAutoComplete}
								class="h-8 press rounded-[2px] px-2.5 text-xs font-semibold text-anime-soft hover:bg-white/5"
							>
								Undo
							</button>
						</div>
					{:else if completion}
						<!-- already at the end when opened (e.g. set elsewhere) -->
						<div
							class="flex items-center gap-2.5 rounded-[2px] border px-3 py-2"
							style="background:rgba(78,217,138,.1);border-color:rgba(78,217,138,.3)"
							role="status"
						>
							<span class="material-symbols-rounded !text-[20px] text-green" aria-hidden="true"
								>task_alt</span
							>
							<div class="flex-1 text-[13px]">
								Last {isAnime ? 'episode' : 'chapter'}. Mark as completed?
							</div>
							<button
								type="button"
								onclick={() => setStatus('COMPLETED')}
								class="h-8 press rounded-[2px] px-2.5 text-xs font-semibold"
								style="background:var(--color-green);color:#06210F"
							>
								Complete
							</button>
						</div>
					{/if}
					{#if !isAnime}
						{@render sectionLabel('Volumes')}
						{@render stepper(
							'volume',
							draft.progressVolumes,
							totals.volumes ? String(totals.volumes) : '?',
							(n) => edit(withVolumes(draft, n, totals)),
							'VOL'
						)}
					{/if}
				</section>

				<!-- 3. Score, in the viewer's own scoring format -->
				<section class="flex flex-col gap-2.5">
					<div class="flex items-baseline justify-between">
						{@render sectionLabel('Score', 'editor-score')}
						<div class="flex items-center gap-2">
							<span class="font-mono text-sm">
								{formatScore(draft.score, session.scoreFormat)}{scale.max >= 10 && draft.score
									? ` / ${scale.max}`
									: ''}
							</span>
							{#if draft.score}
								<button
									type="button"
									onclick={() => edit({ ...draft, score: 0 })}
									class="text-xs font-semibold text-muted hover:text-ink">Clear</button
								>
							{/if}
						</div>
					</div>
					{#if scoreCells.length}
						<div class="flex gap-1" role="group" aria-labelledby="editor-score">
							{#each scoreCells as n (n)}
								<button
									type="button"
									onclick={() => pickScore(n)}
									aria-label="Score {n}"
									aria-pressed={draft.score >= n - 0.5 && draft.score > 0 ? 'true' : 'false'}
									class="grid h-9 flex-1 press place-items-center rounded-[2px] text-xs font-semibold"
									style="background:{cellFill(n)};color:{n <= Math.floor(draft.score)
										? '#2A1B02'
										: 'var(--color-muted)'}"
								>
									{session.scoreFormat === 'POINT_3' ? SMILEYS[n - 1] : n}
								</button>
							{/each}
						</div>
					{:else}
						<input
							type="range"
							min="0"
							max={scale.max}
							step={scale.step}
							value={draft.score}
							oninput={(e) => edit({ ...draft, score: Number(e.currentTarget.value) })}
							aria-labelledby="editor-score"
							class="w-full"
							style="accent-color:var(--color-gold)"
						/>
					{/if}
					<div class="text-xs text-dim">
						Uses your AniList scoring format{halfPoints
							? ' (10-point). Click twice for half points.'
							: '.'}
					</div>
				</section>

				<!-- below the fold: rows on mobile, open on desktop -->
				<section class="flex flex-col gap-4 border-t border-line pt-5">
					<div class="flex flex-col gap-2.5">
						<button
							type="button"
							class="flex items-center justify-between text-left lg:hidden"
							aria-expanded={expanded.dates}
							onclick={() => (expanded.dates = !expanded.dates)}
						>
							<span class="text-sm">Dates</span>
							<span class="flex items-center gap-1 text-[13px] text-muted">
								{draft.startedAt || '—'} → {draft.completedAt || '—'}
								<span class="material-symbols-rounded !text-[20px]" aria-hidden="true"
									>{expanded.dates ? 'expand_less' : 'chevron_right'}</span
								>
							</span>
						</button>
						<div class="grid grid-cols-2 gap-2.5 {expanded.dates ? '' : 'hidden'} lg:grid">
							<label class="flex flex-col gap-1.5 text-xs text-dim">
								Started
								<input
									type="date"
									value={draft.startedAt}
									max={todayInput()}
									onchange={(e) => edit({ ...draft, startedAt: e.currentTarget.value })}
									class="h-10 rounded-[2px] border border-line bg-canvas px-3 font-mono text-sm text-ink"
								/>
							</label>
							<label class="flex flex-col gap-1.5 text-xs text-dim">
								Finished
								<input
									type="date"
									value={draft.completedAt}
									max={todayInput()}
									onchange={(e) => edit({ ...draft, completedAt: e.currentTarget.value })}
									class="h-10 rounded-[2px] border border-line bg-canvas px-3 font-mono text-sm text-ink"
								/>
							</label>
						</div>
					</div>

					<div class="flex flex-col gap-2.5">
						<button
							type="button"
							class="flex items-center justify-between text-left lg:hidden"
							aria-expanded={expanded.repeat}
							onclick={() => (expanded.repeat = !expanded.repeat)}
						>
							<span class="text-sm">{isAnime ? 'Rewatches' : 'Rereads'}</span>
							<span class="flex items-center gap-1 text-[13px] text-muted">
								{draft.repeat}
								<span class="material-symbols-rounded !text-[20px]" aria-hidden="true"
									>{expanded.repeat ? 'expand_less' : 'chevron_right'}</span
								>
							</span>
						</button>
						<div
							class="flex items-center justify-between gap-3 {expanded.repeat
								? ''
								: 'hidden'} lg:flex"
						>
							<div class="flex flex-col gap-0.5">
								<span class="text-sm">Total {isAnime ? 'rewatches' : 'rereads'}</span>
								<span class="text-xs text-dim">Counted in stats</span>
							</div>
							<div class="flex items-center gap-1.5">
								<button
									type="button"
									onclick={() => edit({ ...draft, repeat: Math.max(0, draft.repeat - 1) })}
									disabled={draft.repeat <= 0}
									aria-label="One less {isAnime ? 'rewatch' : 'reread'}"
									class="grid h-9 w-9 press place-items-center btn-quiet disabled:opacity-40"
								>
									<span class="material-symbols-rounded !text-[20px]" aria-hidden="true"
										>remove</span
									>
								</button>
								<span class="w-8 text-center font-mono text-sm">{draft.repeat}</span>
								<button
									type="button"
									onclick={() => edit({ ...draft, repeat: draft.repeat + 1 })}
									aria-label="One more {isAnime ? 'rewatch' : 'reread'}"
									class="grid h-9 w-9 press place-items-center btn-quiet"
								>
									<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">add</span>
								</button>
							</div>
						</div>
					</div>

					<div class="flex flex-col gap-2.5">
						<button
							type="button"
							class="flex items-center justify-between text-left lg:hidden"
							aria-expanded={expanded.notes}
							onclick={() => (expanded.notes = !expanded.notes)}
						>
							<span class="text-sm">Notes</span>
							<span class="flex items-center gap-1 text-[13px] text-muted">
								{draft.notes ? 'Edit' : 'Add'}
								<span class="material-symbols-rounded !text-[20px]" aria-hidden="true"
									>{expanded.notes ? 'expand_less' : 'chevron_right'}</span
								>
							</span>
						</button>
						<label class="flex flex-col gap-1.5 {expanded.notes ? '' : 'hidden'} lg:flex">
							<span
								class="hidden text-[11px] font-semibold tracking-wider text-dim uppercase lg:block"
								>Notes</span
							>
							<textarea
								rows="3"
								value={draft.notes}
								oninput={(e) => edit({ ...draft, notes: e.currentTarget.value })}
								placeholder="Add a note…"
								class="resize-y rounded-[2px] border border-line bg-canvas px-3 py-2 text-sm text-ink placeholder:text-dim"
								aria-label="Notes"></textarea>
						</label>
					</div>

					{#if customLists.length}
						<!-- the custom lists it's on: toggled here, saved with the rest -->
						<div class="flex flex-col gap-2" role="group" aria-labelledby="editor-custom-lists">
							<span
								id="editor-custom-lists"
								class="text-[11px] font-semibold tracking-wider text-dim uppercase"
								>Custom lists</span
							>
							<div class="flex flex-wrap gap-1.5">
								{#each customLists as name (name)}
									{@const on = draft.customLists.includes(name)}
									<button
										type="button"
										aria-pressed={on}
										disabled={!listsKnown}
										title={listsKnown ? undefined : 'Loading the lists it’s on…'}
										onclick={() => edit(withCustomList(draft, name, customLists))}
										class="flex min-h-9 items-center gap-1 rounded-[2px] border px-3 text-[13px] disabled:opacity-50 {on
											? 'border-white/30 bg-raised-hover font-semibold text-ink'
											: 'border-line bg-canvas text-muted hover:text-ink'}"
									>
										<span class="material-symbols-rounded !text-[16px]" aria-hidden="true"
											>{on ? 'check' : 'add'}</span
										>
										{name}
									</button>
								{/each}
							</div>
						</div>
					{/if}

					<button
						type="button"
						role="switch"
						aria-checked={draft.private}
						onclick={() => edit({ ...draft, private: !draft.private })}
						class="flex items-center justify-between text-left"
					>
						<span class="flex flex-col gap-0.5">
							<span class="text-sm">Private entry</span>
							<span class="text-xs text-dim">Hidden from your public profile</span>
						</span>
						<span
							class="h-[26px] w-11 flex-none rounded-full p-[3px] transition-colors"
							style="background:{draft.private ? 'var(--color-ink)' : 'var(--color-raised-hover)'}"
							aria-hidden="true"
						>
							<span
								class="block h-5 w-5 rounded-full transition-transform"
								style="transform:translateX({draft.private
									? '18px'
									: '0'});background:{draft.private ? 'var(--color-surface)' : 'var(--color-ink)'}"
							></span>
						</span>
					</button>
				</section>
			</div>

			<footer class="flex flex-col gap-2.5 border-t border-line px-5 pt-3 pb-6 lg:pb-4">
				{#if error}
					<p class="m-0 text-sm text-[#FF8FA8]" role="alert">{error}</p>
				{/if}
				{#if confirmDiscard}
					<div
						class="flex items-center gap-2 rounded-[2px] bg-canvas px-3 py-2"
						role="alertdialog"
						aria-label="Discard changes?"
					>
						<span class="flex-1 text-sm">Discard your changes?</span>
						<button
							type="button"
							onclick={() => (confirmDiscard = false)}
							class="h-9 rounded-[2px] px-3 text-sm font-semibold text-muted hover:text-ink"
							>Keep editing</button
						>
						<button
							type="button"
							onclick={() => editor.close()}
							class="h-9 rounded-[2px] bg-raised-hover px-3 text-sm font-semibold text-[#FF8FA8]"
							>Discard</button
						>
					</div>
				{:else if confirmDelete}
					<div
						class="flex items-center gap-2 rounded-[2px] bg-canvas px-3 py-2"
						role="alertdialog"
						aria-label="Remove from list?"
					>
						<span class="flex-1 text-sm">Remove it from your list?</span>
						<button
							type="button"
							onclick={() => (confirmDelete = false)}
							class="h-9 rounded-[2px] px-3 text-sm font-semibold text-muted hover:text-ink"
							>Cancel</button
						>
						<button
							type="button"
							onclick={remove}
							disabled={saving}
							class="h-9 rounded-[2px] px-3 text-sm font-semibold"
							style="background:var(--color-pink);color:#2B0710">Remove</button
						>
					</div>
				{/if}
				<div class="flex items-center gap-3">
					{#if !isNew}
						<button
							type="button"
							onclick={() => (confirmDelete = true)}
							disabled={saving || loading}
							class="flex h-10 items-center gap-1 rounded-[2px] px-2 text-sm font-semibold text-[#FF8FA8] hover:bg-white/5 disabled:opacity-50"
						>
							<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">delete</span>
							<span class="lg:inline">Delete</span>
						</button>
					{/if}
					<div class="flex-1 text-right text-xs text-muted" role="status">
						{#if saving}
							Saving…
						{:else if saved}
							<span class="text-green">Saved to AniList ✓</span>
						{/if}
					</div>
					<button
						type="button"
						onclick={() => (dirty || isNew ? save() : editor.close())}
						disabled={saving || loading}
						class="h-11 press btn-ink px-5 text-sm disabled:opacity-60"
					>
						{isNew ? 'Add to list' : dirty ? 'Save' : 'Done'}
					</button>
				</div>
			</footer>
		</div>
	{/if}
</dialog>
