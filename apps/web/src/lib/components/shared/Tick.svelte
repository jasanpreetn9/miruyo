<script lang="ts">
	import { onMount } from 'svelte';

	// A number that ticks: when it changes (a +1), the new one comes up from
	// below. It doesn't on first show, so a page doesn't open with every
	// counter moving.

	interface Props {
		value: number | string;
	}

	let { value }: Props = $props();

	let mounted = $state(false);
	onMount(() => (mounted = true));
</script>

{#key value}<span class={mounted ? 'tick' : ''}>{value}</span>{/key}
