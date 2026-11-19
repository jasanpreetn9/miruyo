<script lang="ts">
	import type { Title } from '#lib/catalog/types.ts';

	// A title's cover as a lazy-loaded image that fills its frame. The frame
	// (the parent: `relative overflow-hidden`, a fixed size or aspect ratio,
	// background `title.placeholder`) shows the colour gradient until the
	// image arrives, then the image fades in. Nothing loads until it's near
	// the viewport, unless `eager`.

	interface Props {
		title: Pick<Title, 'coverUrl' | 'thumbUrl' | 'thumbSmallUrl'>;
		/** The smaller image, for thumbnails. */
		thumb?: boolean;
		/** Above the fold: load right away. */
		eager?: boolean;
		/** The page's largest image (its LCP): load right away, ahead of the rest. */
		priority?: boolean;
		class?: string;
	}

	let {
		title,
		thumb = false,
		eager = false,
		priority = false,
		class: className = ''
	}: Props = $props();

	const src = $derived(thumb ? (title.thumbUrl ?? title.coverUrl) : title.coverUrl);
	// thumbnails are at most 48px wide: the 100px cover does up to 2x screens,
	// the 230px one above that (the browser picks)
	const srcset = $derived(
		thumb && title.thumbUrl && title.thumbSmallUrl
			? `${title.thumbSmallUrl} 100w, ${title.thumbUrl} 230w`
			: undefined
	);
	/** The src that has finished loading; a new src fades in afresh. */
	let loadedSrc = $state<string | undefined>();
	const loaded = $derived(!!src && loadedSrc === src);

	/**
	 * Hydration keeps a server-rendered src even when it's wrong (the
	 * schedule's days move with the viewer's timezone, so a slot can render
	 * another title's cover on the server): put the right one in. Otherwise,
	 * a cached image can finish before the load listener is attached.
	 */
	function whenLoaded(img: HTMLImageElement) {
		if (src && img.getAttribute('src') !== src) img.setAttribute('src', src);
		else if (img.complete && img.naturalWidth) loadedSrc = img.getAttribute('src') ?? undefined;
	}
</script>

{#if src}
	<img
		{src}
		{srcset}
		sizes={srcset ? '48px' : undefined}
		alt=""
		aria-hidden="true"
		loading={eager || priority ? 'eager' : 'lazy'}
		fetchpriority={priority ? 'high' : 'auto'}
		decoding="async"
		draggable="false"
		onload={() => (loadedSrc = src)}
		{@attach whenLoaded}
		class="pointer-events-none absolute inset-0 h-full w-full object-cover transition-opacity duration-300 {loaded
			? 'opacity-100'
			: 'opacity-0'} {className}"
	/>
{/if}
