<script lang="ts">
	interface Props {
		class?: string;
	}

	let { class: className = '' }: Props = $props();
</script>

<div class="skeleton-shimmer rounded-[2px] {className}"></div>
