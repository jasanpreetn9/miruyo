<script lang="ts">
	import type { Snippet } from 'svelte';
	import { page } from '$app/state';
	import Navbar from '#lib/components/shared/Navbar.svelte';
	import Footer from '#lib/components/shared/Footer.svelte';
	import TabBar from '#lib/components/shared/TabBar.svelte';
	import { LEGAL, LEGAL_PAGES } from '#lib/legal.ts';

	// The shell every legal document shares: the title, when it last changed,
	// links between the documents, then the document itself as long-form text.

	interface Props {
		title: string;
		/** One or two sentences in plain words, shown above the full text. */
		summary: Snippet;
		children: Snippet;
	}

	let { title, summary, children }: Props = $props();
</script>

<svelte:head>
	<title>{title} · {LEGAL.app}</title>
</svelte:head>

<div class="min-h-screen bg-canvas pb-28 lg:pb-0">
	<Navbar />

	<main class="mx-auto flex max-w-2xl flex-col gap-7 px-4 pt-5 lg:gap-9 lg:px-6 lg:pt-10">
		<div class="flex flex-col gap-3">
			<nav aria-label="Legal documents" class="flex flex-wrap gap-1.5">
				{#each LEGAL_PAGES as p (p.href)}
					{@const on = page.url.pathname === p.href}
					<a
						href={p.href}
						aria-current={on ? 'page' : undefined}
						class="flex h-9 items-center rounded-[2px] border px-3.5 text-[13px] font-semibold {on
							? 'border-transparent bg-raised-hover text-ink hover:text-ink'
							: 'border-line text-muted hover:bg-white/5 hover:text-ink'}">{p.label}</a
					>
				{/each}
			</nav>
			<h1
				class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				{title}
			</h1>
			<p class="m-0 text-sm text-dim">Last updated {LEGAL.updated}</p>
		</div>

		<div class="border-l-2 border-anime pl-4 text-[15px] leading-relaxed text-muted lg:pl-5">
			{@render summary()}
		</div>

		<article class="legal">
			{@render children()}
		</article>
	</main>

	<Footer />
</div>

<TabBar active="profile" />

<style>
	.legal {
		display: flex;
		flex-direction: column;
		gap: 0.9rem;
		font-size: 15px;
		line-height: 1.7;
		color: var(--color-muted);
	}
	.legal :global(h2) {
		margin: 1.4rem 0 0;
		font-family: var(--font-display);
		font-size: 1.25rem;
		font-weight: 650;
		letter-spacing: -0.01em;
		color: var(--color-ink);
		scroll-margin-top: 5rem;
	}
	.legal :global(h3) {
		margin: 0.6rem 0 0;
		font-size: 15px;
		font-weight: 600;
		color: var(--color-ink);
	}
	.legal :global(p),
	.legal :global(ul),
	.legal :global(ol) {
		margin: 0;
	}
	.legal :global(ul),
	.legal :global(ol) {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
		padding-left: 1.25rem;
	}
	.legal :global(ul) {
		list-style: disc;
	}
	.legal :global(ol) {
		list-style: decimal;
	}
	.legal :global(strong) {
		font-weight: 600;
		color: var(--color-ink);
	}
	.legal :global(code) {
		font-family: var(--font-mono);
		font-size: 13px;
		color: var(--color-ink);
	}
	.legal :global(.caps) {
		font-size: 13px;
		letter-spacing: 0.01em;
	}
	.legal :global(.table-wrap) {
		overflow-x: auto;
		border-radius: 1rem;
		border: 1px solid var(--color-line);
	}
	.legal :global(table) {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
		line-height: 1.55;
	}
	.legal :global(th),
	.legal :global(td) {
		padding: 0.6rem 0.8rem;
		text-align: left;
		vertical-align: top;
		border-top: 1px solid var(--color-line);
	}
	.legal :global(thead th) {
		border-top: 0;
		background: var(--color-raised);
		font-weight: 600;
		color: var(--color-ink);
	}
</style>
