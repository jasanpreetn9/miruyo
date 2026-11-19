<script lang="ts">
	import { goto } from '$app/navigation';
	import { coverBackground } from '#lib/anilist/adapt.ts';
	import type { ViewerSettings } from '#lib/anilist/client.ts';
	import { formatScore } from '#lib/anilist/score.ts';
	import {
		baseTitleLanguage,
		TITLE_LANGUAGES,
		type BaseTitleLanguage
	} from '#lib/anilist/title-language.ts';
	import type { ScoreFormat, TitleLanguage } from '#lib/anilist/types.ts';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import { session } from '#lib/state/session.svelte.ts';

	// Settings (no design yet; built in the existing style). Everything here
	// is saved to the AniList account — miruyo follows it rather than keeping
	// its own copy — so each change saves as soon as it's made.

	const SCORE_FORMATS: { key: ScoreFormat; name: string; example: number }[] = [
		{ key: 'POINT_10_DECIMAL', name: '10 points, with decimals', example: 8.5 },
		{ key: 'POINT_10', name: '10 points', example: 8 },
		{ key: 'POINT_100', name: '100 points', example: 85 },
		{ key: 'POINT_5', name: '5 stars', example: 4 },
		{ key: 'POINT_3', name: '3 smileys', example: 3 }
	];

	/** Keeps the account's "stylised" choice (official casing) when switching language. */
	function withStyle(lang: BaseTitleLanguage): TitleLanguage {
		const current = session.user?.options?.titleLanguage;
		return current?.endsWith('_STYLISED') ? (`${lang}_STYLISED` as TitleLanguage) : lang;
	}

	// ── Saving: show the change at once, roll back if AniList refuses it ──
	type Field = keyof Required<ViewerSettings>;
	let pending = $state<ViewerSettings>({});
	let saving = $state<Field | null>(null);
	let status = $state<{ ok: boolean; text: string } | null>(null);

	const options = $derived(session.user?.options);
	const lang = $derived(baseTitleLanguage(pending.titleLanguage ?? options?.titleLanguage));
	const adult = $derived(pending.displayAdultContent ?? options?.displayAdultContent ?? false);
	const airing = $derived(pending.airingNotifications ?? options?.airingNotifications ?? true);
	const scoreFormat = $derived(pending.scoreFormat ?? session.scoreFormat);

	async function save(field: Field, patch: ViewerSettings) {
		if (saving) return;
		saving = field;
		status = null;
		pending = patch;
		try {
			await session.updateSettings(patch);
			status = { ok: true, text: 'Saved to AniList' };
		} catch (err) {
			console.error('Failed to save settings:', err);
			status = {
				ok: false,
				text: `Couldn't save to AniList${err instanceof Error ? ` (${err.message})` : ''}. Nothing was changed.`
			};
		} finally {
			pending = {};
			saving = null;
		}
	}

	function handleLogout() {
		session.logout();
		void goto('/login');
	}

	const isAnime = $derived(session.mode === 'anime');
	const accent = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');
</script>

<svelte:head>
	<title>Settings · miruyo</title>
</svelte:head>

{#snippet toggle(on: boolean, labelId: string, onclick: () => void, busy: boolean)}
	<button
		type="button"
		role="switch"
		aria-checked={on}
		aria-labelledby={labelId}
		aria-busy={busy}
		disabled={!!saving}
		{onclick}
		class="touch-target relative h-[26px] w-11 flex-none rounded-full p-[3px] disabled:opacity-70"
		style="background:{on ? accent : 'var(--color-raised-hover)'}"
	>
		<span
			class="block h-5 w-5 rounded-full bg-ink transition-transform duration-(--duration-lift) ease-enter"
			style="transform:translateX({on ? '18px' : '0'})"
		></span>
	</button>
{/snippet}

{#snippet sectionHeading(text: string, id: string)}
	<h2 class="m-0 px-1 font-display text-lg font-medium tracking-[-0.01em] lg:text-xl" {id}>
		{text}
	</h2>
{/snippet}

<PageShell tab="profile" pad="pb-28 lg:pb-0">
	{#if session.authState === 'out'}
		<div class="flex flex-col items-center gap-3 px-6 py-24 text-center">
			<span class="material-symbols-rounded !text-[40px] text-dim" aria-hidden="true">tune</span>
			<h1
				class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				Settings live on your AniList account
			</h1>
			<p class="m-0 max-w-sm text-sm text-muted">
				Log in to choose how titles are shown, how you score, and what AniList tells you about.
			</p>
			<a href="/login" class="mt-2 flex h-12 items-center btn-ink px-5 hover:text-canvas"
				>Log in with AniList</a
			>
		</div>
	{:else}
		<div class="mx-auto flex max-w-2xl flex-col gap-7 px-4 pt-5 lg:gap-9 lg:px-6 lg:pt-10">
			<div class="flex flex-col gap-1.5">
				<h1
					class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
				>
					Settings
				</h1>
				<p class="m-0 text-sm text-muted">
					Saved to your AniList account, so they match everywhere you use AniList.
				</p>
				<!-- the save status: a line under the intro, not a row (and a gap) of its own -->
				<div class="min-h-5 text-sm" role="status" aria-live="polite" data-testid="save-status">
					{#if saving}
						<span class="text-muted">Saving…</span>
					{:else if status}
						<span class="flex items-center gap-1.5 {status.ok ? 'text-green' : 'text-[#FF8FA8]'}">
							<span class="material-symbols-rounded !text-[18px]" aria-hidden="true"
								>{status.ok ? 'check_circle' : 'error'}</span
							>
							{status.text}
						</span>
					{/if}
				</div>
			</div>

			{#if session.authState === 'error'}
				<div class="flex flex-col items-start gap-3 border-y border-line py-5">
					<p class="m-0 text-sm text-muted">
						Couldn't reach AniList to load your settings.
						{#if session.retry.active}
							Trying again in <span class="font-mono text-ink">{session.retry.label}</span>.
						{/if}
					</p>
					<button
						onclick={() => session.loadCurrentUser()}
						class="h-11 btn-quiet px-4 text-sm font-semibold"
					>
						Retry now
					</button>
				</div>
			{:else if session.authState === 'loading' || !session.user}
				<div class="flex flex-col gap-4" aria-busy="true" aria-label="Loading your settings">
					<Skeleton class="h-6 w-32" />
					<Skeleton class="h-48 rounded-[2px]" />
					<Skeleton class="h-6 w-32" />
					<Skeleton class="h-24 rounded-[2px]" />
				</div>
			{:else}
				<!-- Display -->
				<section class="flex flex-col gap-3" aria-labelledby="display-heading">
					{@render sectionHeading('Display', 'display-heading')}
					<div class="flex flex-col gap-2.5 border-t border-ink pt-3.5 lg:pt-4">
						<div class="text-[13px] font-semibold text-muted" id="lang-label">Show titles in</div>
						<div
							class="grid gap-2 lg:grid-cols-3"
							role="radiogroup"
							aria-labelledby="lang-label"
							data-testid="title-language"
						>
							{#each TITLE_LANGUAGES as l (l.key)}
								{@const on = lang === l.key}
								<button
									type="button"
									role="radio"
									aria-checked={on}
									disabled={!!saving}
									onclick={() => {
										if (!on) void save('titleLanguage', { titleLanguage: withStyle(l.key) });
									}}
									class="flex min-h-[60px] items-center gap-3 rounded-[2px] border px-3.5 py-2.5 text-left disabled:cursor-default"
									style="background:{on
										? 'var(--color-raised-hover)'
										: 'var(--color-canvas)'};border-color:{on
										? `color-mix(in oklch, ${accent} 50%, transparent)`
										: 'rgba(255,255,255,.06)'}"
								>
									<span
										class="h-5 w-5 flex-none rounded-full"
										style="border:{on ? `6px solid ${accent}` : '2px solid rgba(255,255,255,.25)'}"
										aria-hidden="true"
									></span>
									<span class="flex min-w-0 flex-col gap-0.5">
										<span class="text-sm font-semibold">{l.name}</span>
										<span
											class="truncate text-[13px] text-muted"
											lang={l.key === 'NATIVE' ? 'ja' : undefined}>{l.example}</span
										>
									</span>
								</button>
							{/each}
						</div>

						<div class="mt-1.5 flex items-center justify-between gap-4 border-t border-line pt-3.5">
							<div class="flex flex-col gap-0.5">
								<div class="text-sm font-medium" id="adult-label">Show adult (18+) titles</div>
								<div class="text-xs text-dim">Off: hidden from feeds, and covers are blurred</div>
							</div>
							{@render toggle(
								adult,
								'adult-label',
								() => save('displayAdultContent', { displayAdultContent: !adult }),
								saving === 'displayAdultContent'
							)}
						</div>
					</div>
				</section>

				<!-- Scoring -->
				<section class="flex flex-col gap-3" aria-labelledby="scoring-heading">
					{@render sectionHeading('Scoring', 'scoring-heading')}
					<div class="flex flex-col gap-2.5 border-t border-ink pt-3.5 lg:pt-4">
						<div class="text-[13px] font-semibold text-muted" id="score-label">
							Score titles out of
						</div>
						<div
							class="flex flex-col gap-1"
							role="radiogroup"
							aria-labelledby="score-label"
							data-testid="score-format"
						>
							{#each SCORE_FORMATS as f (f.key)}
								{@const on = scoreFormat === f.key}
								<button
									type="button"
									role="radio"
									aria-checked={on}
									disabled={!!saving}
									onclick={() => {
										if (!on) void save('scoreFormat', { scoreFormat: f.key });
									}}
									class="flex min-h-12 items-center gap-3 rounded-[2px] px-3 text-left disabled:cursor-default {on
										? 'bg-raised-hover'
										: 'hover:bg-white/3'}"
								>
									<span
										class="h-5 w-5 flex-none rounded-full"
										style="border:{on ? `6px solid ${accent}` : '2px solid rgba(255,255,255,.25)'}"
										aria-hidden="true"
									></span>
									<span class="flex-1 text-sm font-medium">{f.name}</span>
									<span class="font-mono text-sm text-muted">{formatScore(f.example, f.key)}</span>
								</button>
							{/each}
						</div>
						<p class="m-0 border-t border-line pt-3 text-xs leading-relaxed text-dim">
							Changing this doesn't lose anything: AniList keeps every score and shows it in the new
							format. Scores show rounded on the smaller scales.
						</p>
					</div>
				</section>

				<!-- Notifications -->
				<section class="flex flex-col gap-3" aria-labelledby="notifications-heading">
					{@render sectionHeading('Notifications', 'notifications-heading')}
					<div class="flex items-center justify-between gap-4 border-t border-ink pt-3.5 lg:pt-4">
						<div class="flex flex-col gap-0.5">
							<div class="text-sm font-medium" id="airing-label">New episodes</div>
							<div class="text-xs leading-relaxed text-dim">
								AniList tells you when an episode of something you're watching airs.
							</div>
						</div>
						{@render toggle(
							airing,
							'airing-label',
							() => save('airingNotifications', { airingNotifications: !airing }),
							saving === 'airingNotifications'
						)}
					</div>
				</section>

				<!-- Account -->
				<section class="flex flex-col gap-3" aria-labelledby="account-heading">
					{@render sectionHeading('Account', 'account-heading')}
					<div class="flex flex-col border-t border-ink">
						<div class="flex items-center gap-3 px-2 py-2.5">
							<div
								class="h-11 w-11 flex-none rounded-full bg-[linear-gradient(135deg,#5AB0FF,#A08CFF)]"
								style={session.user.avatar.large
									? `background:${coverBackground(session.user.avatar.large)}`
									: ''}
								aria-hidden="true"
							></div>
							<div class="flex min-w-0 flex-1 flex-col">
								<div class="text-xs text-dim">Signed in as</div>
								<div class="truncate font-semibold">{session.user.name}</div>
							</div>
							<a
								href="https://anilist.co/user/{encodeURIComponent(session.user.name)}"
								target="_blank"
								rel="noreferrer"
								class="flex h-11 items-center gap-1 rounded-[2px] px-3 text-sm font-semibold text-ink hover:bg-white/5 hover:text-ink"
							>
								Profile
								<span class="material-symbols-rounded !text-[16px] text-dim" aria-hidden="true"
									>open_in_new</span
								>
							</a>
						</div>

						{#snippet externalRow(href: string, icon: string, label: string, detail: string)}
							<a
								{href}
								target="_blank"
								rel="noreferrer"
								class="flex min-h-14 items-center gap-3 rounded-[2px] border-t border-line px-2 py-2.5 text-ink hover:bg-white/5 hover:text-ink"
							>
								<span class="material-symbols-rounded !text-[22px] text-muted" aria-hidden="true"
									>{icon}</span
								>
								<span class="flex flex-1 flex-col gap-0.5">
									<span class="text-sm font-medium">{label}</span>
									<span class="text-xs text-dim">{detail}</span>
								</span>
								<span class="material-symbols-rounded !text-[18px] text-dim" aria-hidden="true"
									>open_in_new</span
								>
							</a>
						{/snippet}

						{@render externalRow(
							'https://anilist.co/settings',
							'settings',
							'More settings on AniList',
							'Notification types, list layout, profile and more'
						)}
						{@render externalRow(
							'https://anilist.co/settings/apps',
							'key_off',
							'Revoke access',
							'Disconnect miruyo from your AniList account'
						)}

						<button
							type="button"
							onclick={handleLogout}
							class="flex min-h-14 items-center gap-3 rounded-[2px] border-t border-line px-2 text-left text-[#FF8FA8] hover:bg-[rgba(255,107,139,.08)]"
						>
							<span class="material-symbols-rounded !text-[22px]" aria-hidden="true">logout</span>
							<span class="flex flex-col gap-0.5">
								<span class="text-sm font-medium">Sign out</span>
								<span class="text-xs text-dim">On this browser only</span>
							</span>
						</button>
					</div>
				</section>
			{/if}
		</div>
	{/if}
</PageShell>
