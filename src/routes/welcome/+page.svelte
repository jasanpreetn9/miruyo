<script lang="ts">
	import { goto } from '$app/navigation';
	import { fetchViewerCounts } from '#lib/anilist/client.ts';
	import {
		baseTitleLanguage,
		TITLE_LANGUAGES,
		type BaseTitleLanguage
	} from '#lib/anilist/title-language.ts';
	import { writePref } from '#lib/state/prefs.ts';
	import { session, type Mode } from '#lib/state/session.svelte.ts';
	import { ONBOARDED_STORAGE_KEY } from '#lib/storage-keys.ts';

	// First-run setup (design 9c): default mode, title language and adult
	// content, then go. Title language and adult content live on the AniList
	// account — miruyo follows them — so they're saved there.

	const MODES: { key: Mode; name: string; icon: string }[] = [
		{ key: 'anime', name: 'Anime', icon: 'play_circle' },
		{ key: 'manga', name: 'Manga', icon: 'menu_book' }
	];

	let mode = $state<Mode>(session.mode);
	let lang = $state<BaseTitleLanguage>('ROMAJI');
	let adult = $state(false);
	let counts = $state<{ anime: number; manga: number } | null>(null);
	let saving = $state(false);
	let error = $state('');
	let prefilled = false;

	$effect(() => {
		if (session.authState === 'out') void goto('/login', { replace: true });
	});

	// once the account is loaded, start from its current settings and counts
	$effect(() => {
		const user = session.user;
		if (session.authState !== 'in' || !user || prefilled) return;
		prefilled = true;
		lang = baseTitleLanguage(user.options?.titleLanguage);
		adult = user.options?.displayAdultContent ?? false;
		fetchViewerCounts()
			.then((c) => (counts = c))
			.catch((err) => console.error('Failed to load list counts:', err));
	});

	function finish() {
		writePref(ONBOARDED_STORAGE_KEY, '1');
		void goto('/', { replace: true });
	}

	async function save() {
		if (saving) return;
		saving = true;
		error = '';
		session.setMode(mode);
		const options = session.user?.options;
		const langChanged = baseTitleLanguage(options?.titleLanguage) !== lang;
		const adultChanged = (options?.displayAdultContent ?? false) !== adult;
		try {
			if (langChanged || adultChanged) {
				await session.updateSettings({
					titleLanguage: langChanged ? lang : undefined,
					displayAdultContent: adultChanged ? adult : undefined
				});
			}
			finish();
		} catch (err) {
			console.error('Failed to save settings:', err);
			error = `Couldn't save to AniList${err instanceof Error ? ` (${err.message})` : ''}. Try again, or skip for now.`;
		} finally {
			saving = false;
		}
	}

	const accent = $derived(mode === 'manga' ? 'var(--color-manga)' : 'var(--color-anime)');
	const accentInk = $derived(
		mode === 'manga' ? 'var(--color-manga-ink)' : 'var(--color-anime-ink)'
	);
</script>

<svelte:head>
	<title>Welcome · miruyo</title>
</svelte:head>

<div class="min-h-screen bg-surface text-ink">
	{#if session.authState === 'in' && session.user}
		<main class="mx-auto flex min-h-screen max-w-md flex-col gap-6 px-6 pt-6 pb-9">
			<div class="flex gap-1.5" aria-hidden="true">
				<div class="h-1 flex-1 rounded-full" style="background:{accent}"></div>
				<div class="h-1 flex-1 rounded-full" style="background:{accent}"></div>
				<div class="h-1 flex-1 rounded-full bg-[var(--color-raised-hover)]"></div>
			</div>

			<div
				class="flex items-center gap-3 rounded-[2px] border p-3"
				style="background:rgba(78,217,138,.08);border-color:rgba(78,217,138,.25)"
				role="status"
			>
				<span
					class="material-symbols-rounded !text-[22px] text-green"
					style="font-variation-settings:'FILL' 1"
					aria-hidden="true">check_circle</span
				>
				<div class="text-sm leading-snug">
					Connected as <b>{session.user.name}</b>.
					{#if counts}
						Imported {counts.anime} anime and {counts.manga} manga.
					{/if}
				</div>
			</div>

			<h1
				class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				Make it yours
			</h1>

			<div class="flex flex-col gap-2.5">
				<div class="text-[13px] font-semibold text-muted" id="mode-label">Open the app in</div>
				<div
					class="grid grid-cols-2 gap-1 border-b border-line"
					role="radiogroup"
					aria-labelledby="mode-label"
				>
					{#each MODES as m (m.key)}
						{@const on = mode === m.key}
						<button
							type="button"
							role="radio"
							aria-checked={on}
							onclick={() => (mode = m.key)}
							class="flex h-12 press items-center justify-center gap-1.5 rounded-[2px] text-sm font-semibold"
							style="box-shadow:{on
								? `inset 0 -2px 0 ${m.key === 'manga' ? 'var(--color-manga)' : 'var(--color-anime)'}`
								: 'none'};color:{on ? 'var(--color-ink)' : 'var(--color-muted)'}"
						>
							<span class="material-symbols-rounded !text-[18px]" aria-hidden="true">{m.icon}</span>
							{m.name}
						</button>
					{/each}
				</div>
			</div>

			<div class="flex flex-col gap-2.5">
				<div class="text-[13px] font-semibold text-muted" id="lang-label">Show titles in</div>
				<div class="flex flex-col gap-2.5" role="radiogroup" aria-labelledby="lang-label">
					{#each TITLE_LANGUAGES as l (l.key)}
						{@const on = lang === l.key}
						<button
							type="button"
							role="radio"
							aria-checked={on}
							onclick={() => (lang = l.key)}
							class="flex min-h-[60px] items-center gap-3 rounded-[2px] border px-3.5 py-2.5 text-left"
							style="background:{on
								? 'var(--color-raised-hover)'
								: 'var(--color-raised)'};border-color:{on
								? `color-mix(in oklch, ${accent} 50%, transparent)`
								: 'rgba(255,255,255,.06)'}"
						>
							<span
								class="h-5 w-5 flex-none rounded-full"
								style="border:{on ? `6px solid ${accent}` : '2px solid rgba(255,255,255,.25)'}"
								aria-hidden="true"
							></span>
							<span class="flex flex-col gap-0.5">
								<span class="text-sm font-semibold">{l.name}</span>
								<span class="text-[13px] text-muted" lang={l.key === 'NATIVE' ? 'ja' : undefined}
									>{l.example}</span
								>
							</span>
						</button>
					{/each}
				</div>
			</div>

			<div class="flex items-center justify-between gap-3 border-y border-line py-3.5">
				<div class="flex flex-col gap-0.5">
					<div class="text-sm font-medium" id="adult-label">Show adult (18+) titles</div>
					<div class="text-xs text-dim">Off: hidden and blurred everywhere</div>
				</div>
				<button
					type="button"
					role="switch"
					aria-checked={adult}
					aria-labelledby="adult-label"
					onclick={() => (adult = !adult)}
					class="h-[26px] w-11 flex-none rounded-full p-[3px]"
					style="background:{adult ? accent : 'var(--color-raised-hover)'}"
				>
					<span
						class="block h-5 w-5 rounded-full bg-ink transition-transform duration-(--duration-lift) ease-enter"
						style="transform:translateX({adult ? '18px' : '0'})"
					></span>
				</button>
			</div>

			<p class="m-0 text-xs leading-relaxed text-dim">
				Title language and adult content are saved to your AniList account, so they match everywhere
				you use AniList.
			</p>

			<div class="mt-auto flex flex-col gap-2.5 pt-2">
				{#if error}
					<p class="m-0 text-sm text-[#FF8FA8]" role="alert">{error}</p>
				{/if}
				<button
					onclick={save}
					disabled={saving}
					class="h-14 press rounded-[2px] text-[17px] font-semibold disabled:opacity-60"
					style="background:{accent};color:{accentInk}"
				>
					{saving ? 'Saving…' : 'Continue'}
				</button>
				{#if error}
					<button onclick={finish} class="h-11 text-sm font-semibold text-muted hover:text-ink">
						Skip for now
					</button>
				{/if}
			</div>
		</main>
	{:else if session.authState === 'error'}
		<main
			class="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center gap-4 px-6 text-center"
		>
			<p class="m-0 text-sm text-muted">
				Couldn't reach AniList to finish signing in.
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
		</main>
	{:else}
		<main class="flex min-h-screen items-center justify-center" aria-busy="true">
			<div
				class="grid h-12 w-12 animate-pulse place-items-center rounded-[2px] bg-anime font-display text-2xl font-extrabold text-anime-ink"
				aria-label="Loading"
			>
				見
			</div>
		</main>
	{/if}
</div>
