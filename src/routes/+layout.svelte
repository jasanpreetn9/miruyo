<script lang="ts">
	import './layout.css';
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { startAnalytics } from '#lib/analytics.ts';
	import favicon from '#lib/assets/favicon.svg';
	import ListEditor from '#lib/components/shared/ListEditor.svelte';
	import ToastHost from '#lib/components/shared/ToastHost.svelte';
	import { isSearchShortcut, openSearch } from '#lib/state/search.svelte.ts';
	import { routeMeta, SITE_NAME, SITE_URL } from '#lib/seo.ts';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();

	// production only; see analytics.ts for what's sent
	startAnalytics();

	// an error page (a title that doesn't exist) stays out of the index
	const meta = $derived(
		routeMeta(page.status >= 400 ? null : page.route.id, page.status >= 400 ? null : page.data.meta)
	);
	// '<' escaped so a synopsis can't close the script tag
	const jsonLd = $derived(meta.jsonLd && JSON.stringify(meta.jsonLd).replace(/</g, '\\u003c'));
	// the canonical address drops the query string (filters, sort, ?type=manga)
	// unless the page names one
	const url = $derived(SITE_URL + (meta.canonical ?? page.url.pathname));

	// Marks the page interactive. e2e tests wait for this before clicking,
	// since clicks on server-rendered markup before hydration are lost.
	onMount(() => {
		document.documentElement.dataset.hydrated = '';
		// show icons once their font has loaded (see layout.css); if the
		// stylesheet never arrived there's nothing to wait for
		const ready = () => document.documentElement.classList.add('icons-ready');
		document.fonts.load('24px "Material Symbols Rounded"').then(ready, ready);
	});
</script>

<svelte:window
	onkeydown={(e) => {
		if (!isSearchShortcut(e)) return;
		e.preventDefault();
		openSearch();
	}}
/>

<svelte:head>
	<!-- the SVG for browsers that take it; favicon.ico (16–48px PNGs) for the
	     rest and for crawlers; apple-touch-icon for iOS home screens and link
	     previews; the manifest for Android. All made from the app's 1024px icon. -->
	<link rel="icon" href="/favicon.ico" sizes="48x48" />
	<link rel="icon" href={favicon} type="image/svg+xml" />
	<link rel="apple-touch-icon" href="/apple-touch-icon.png" />
	<link rel="manifest" href="/manifest.webmanifest" />
	<meta name="description" content={meta.description} />
	<meta name="theme-color" content="#13110f" />
	{#if meta.noindex}
		<meta name="robots" content="noindex" />
	{:else}
		<link rel="canonical" href={url} />
	{/if}
	<meta property="og:type" content="website" />
	<meta property="og:site_name" content={SITE_NAME} />
	<meta property="og:title" content={meta.title} />
	<meta property="og:description" content={meta.description} />
	<meta property="og:url" content={url} />
	<meta property="og:image" content={meta.image.url} />
	{#if meta.image.width && meta.image.height}
		<meta property="og:image:width" content={String(meta.image.width)} />
		<meta property="og:image:height" content={String(meta.image.height)} />
	{/if}
	<meta property="og:image:alt" content={meta.image.alt} />
	<meta name="twitter:card" content="summary_large_image" />
	{#if jsonLd}
		<!-- data, not a script: CSP doesn't apply to it -->
		{@html `<script type="application/ld+json">${jsonLd}</script>`}
	{/if}
</svelte:head>

{@render children()}

<!-- the app-wide list editor; any page opens it with editor.open(title) -->
<ListEditor />
<ToastHost />
