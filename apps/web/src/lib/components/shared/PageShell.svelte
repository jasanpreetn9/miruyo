<script lang="ts">
	import type { Snippet } from 'svelte';
	import Footer from '#lib/components/shared/Footer.svelte';
	import Navbar from '#lib/components/shared/Navbar.svelte';
	import TabBar from '#lib/components/shared/TabBar.svelte';

	// The main pages' frame: the navbar, the page, the footer and (touch) the
	// tab bar. The page is at least a screen tall, so the footer starts below
	// the fold: it doesn't sit mid-screen on a short page (an error, a short
	// list), and it doesn't jump down as a page's rows load in (Lighthouse
	// counted that as most of Home's layout shift).

	type Section = 'home' | 'browse' | 'seasonal' | 'list' | 'profile';

	interface Props {
		/** The navbar's highlighted section; none on pages outside the nav. */
		nav?: Section;
		/** The tab bar's highlighted tab (pages outside the nav still sit under one). */
		tab: Section;
		/** Bottom padding, clearing the tab bar on touch. */
		pad?: string;
		children: Snippet;
	}

	let { nav, tab, pad = 'pb-24 lg:pb-0', children }: Props = $props();
</script>

<div class="flex min-h-dvh flex-col bg-canvas {pad}">
	<Navbar active={nav} />
	<!-- the page's one main landmark (pages inside the shell don't add their own) -->
	<main class="min-h-dvh min-w-0 flex-1">
		{@render children()}
	</main>
	<Footer />
</div>

<TabBar active={tab} />
