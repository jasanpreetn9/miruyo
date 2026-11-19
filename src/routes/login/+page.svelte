<script lang="ts">
	import { adaptMedia } from '#lib/anilist/adapt.ts';
	import { clientId, fetchPublicTrending } from '#lib/anilist/client.ts';
	import type { Title } from '#lib/catalog/types.ts';
	import { createAuthUrl, newAuthState } from '#lib/page-data/login.ts';
	import { OAUTH_STATE_STORAGE_KEY } from '#lib/storage-keys.ts';

	// The poster wall: what's trending on AniList right now (public, no token).
	// Until it loads — or if AniList is unreachable — the tiles are plain.
	let wall = $state<Title[]>([]);
	$effect(() => {
		Promise.all([fetchPublicTrending('ANIME'), fetchPublicTrending('MANGA')])
			.then(([anime, manga]) => {
				const mixed = anime.flatMap((a, i) => (manga[i] ? [a, manga[i]] : [a]));
				wall = mixed
					.filter((m) => !m.isAdult)
					.map((m) => adaptMedia(m, undefined, { titles: 'english' }));
			})
			.catch((err) => console.error('Failed to load the poster wall:', err));
	});

	type Tile = { key: string; cover: string; glow: string };
	const PLAIN = 'var(--color-raised)';
	function tiles(count: number, from: Title[]): Tile[] {
		return Array.from({ length: count }, (_, i) => {
			const t = from.length ? from[i % from.length] : undefined;
			return { key: `${i}`, cover: t?.cover ?? PLAIN, glow: t?.glow ?? 'none' };
		});
	}
	const wallDesktop = $derived(tiles(24, wall));
	const wallMobile = $derived(tiles(12, [...wall].reverse()));

	// the callback only accepts a token carrying the state this tab saved
	let authUrl = $state(createAuthUrl(clientId));
	$effect(() => {
		const state = newAuthState();
		try {
			sessionStorage.setItem(OAUTH_STATE_STORAGE_KEY, state);
		} catch {
			return; // no storage: the callback couldn't check it anyway
		}
		authUrl = createAuthUrl(clientId, state);
	});
</script>

{#snippet agreement()}
	<p class="m-0 text-center text-xs leading-relaxed text-dim lg:text-left">
		By logging in, you agree to the <a href="/terms">Terms of Use</a> and
		<a href="/privacy">Privacy Policy</a>.
	</p>
{/snippet}

<div class="min-h-screen bg-canvas text-ink">
	<!-- ================= DESKTOP LOGIN ================= -->
	<div class="relative hidden h-screen overflow-hidden lg:block">
		<div
			class="absolute -top-20 -bottom-20 grid grid-cols-6 gap-4"
			style="left:560px;right:-200px;transform:rotate(-8deg)"
		>
			{#each wallDesktop as t (t.key)}
				<div
					class="aspect-2/3 rounded-[2px]"
					style="background:{t.cover};box-shadow:{t.glow}"
				></div>
			{/each}
		</div>
		<div
			class="absolute inset-0"
			style="background:linear-gradient(90deg,#13110F 40%,rgba(19,17,15,.55) 70%,rgba(19,17,15,.3))"
		></div>

		<div class="absolute inset-y-0 left-30 flex w-130 flex-col justify-center gap-7">
			<div class="flex items-center gap-3">
				<div
					class="grid h-11 w-11 place-items-center rounded-[2px] bg-anime font-display text-2xl font-extrabold text-anime-ink"
				>
					見
				</div>
				<div class="font-display text-[28px] font-bold tracking-[-0.02em]">miruyo</div>
			</div>
			<div class="font-display text-[56px] leading-[1.02] font-bold tracking-[-0.035em]">
				Pick up exactly where you left off.
			</div>
			<div class="text-[17px] leading-relaxed text-[#C9BFAE]">
				Your AniList list, made fast: one-tap progress, a weekly airing calendar, and picks that
				explain themselves.
			</div>
			<div class="flex flex-col gap-3">
				<a
					href={authUrl}
					class="flex h-14 items-center justify-center gap-2.5 rounded-[2px] bg-anime text-[17px] font-semibold text-anime-ink transition hover:opacity-90"
				>
					<span
						class="grid h-6.5 w-6.5 place-items-center rounded-[2px] bg-anime-ink font-display text-[13px] font-extrabold text-anime"
					>
						AL
					</span>
					Log in with AniList
				</a>
				<a
					href="/browse"
					class="flex h-12 items-center justify-center rounded-[2px] border border-line text-[15px] font-semibold text-ink hover:bg-white/5"
				>
					Browse without an account
				</a>
			</div>
			<div
				class="flex gap-3 rounded-[2px] border border-line bg-[rgba(29,26,22,.8)] p-4 text-[13px] leading-relaxed text-muted"
			>
				<span class="material-symbols-rounded text-[20px]! text-green">verified_user</span>
				<div>
					You'll approve access on anilist.co. We never see your password, and only read or change
					your list when you ask. Revoke any time in AniList settings.
				</div>
			</div>
			{@render agreement()}
		</div>
	</div>

	<!-- ================= MOBILE LOGIN ================= -->
	<div class="relative h-screen overflow-hidden lg:hidden">
		<div
			class="absolute top-5 -right-16 -left-16 grid grid-cols-4 gap-2.5"
			style="transform:rotate(-8deg)"
		>
			{#each wallMobile as t (t.key)}
				<div class="aspect-2/3 rounded-[2px]" style="background:{t.cover}"></div>
			{/each}
		</div>
		<div
			class="absolute inset-0"
			style="background:linear-gradient(0deg,#13110F 48%,rgba(19,17,15,.2) 85%)"
		></div>

		<div class="absolute right-6 bottom-10 left-6 flex flex-col gap-4">
			<div class="flex items-center gap-2.5">
				<div
					class="grid h-9 w-9 place-items-center rounded-[2px] bg-anime font-display text-xl font-extrabold text-anime-ink"
				>
					見
				</div>
				<div class="font-display text-2xl font-bold">miruyo</div>
			</div>
			<div class="font-display text-[34px] leading-[1.05] font-bold tracking-[-0.035em]">
				Pick up exactly where you left off.
			</div>
			<div class="text-[15px] leading-relaxed text-[#C9BFAE]">
				One-tap progress, airing times in your timezone, picks that explain themselves.
			</div>
			<!-- Unified href with desktop -->
			<a
				href={authUrl}
				class="mt-1.5 flex h-14 items-center justify-center gap-2 rounded-[2px] bg-anime text-[17px] font-semibold text-anime-ink"
			>
				<span
					class="grid h-6 w-6 place-items-center rounded bg-anime-ink font-display text-[12px] font-extrabold text-anime"
				>
					AL
				</span>
				Log in with AniList
			</a>
			<a
				href="/browse"
				class="flex h-12 items-center justify-center text-[15px] font-semibold text-muted"
			>
				Browse without an account
			</a>
			{@render agreement()}
		</div>
	</div>
</div>
