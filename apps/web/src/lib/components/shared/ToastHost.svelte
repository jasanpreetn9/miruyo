<script lang="ts">
	import { fly } from 'svelte/transition';
	import { DURATION } from '#lib/motion.ts';
	import { toast } from '#lib/state/toast.svelte.ts';
</script>

<!-- above the mobile tab bar; a live region so screen readers hear it -->
<div
	class="pointer-events-none fixed inset-x-0 bottom-24 z-[80] flex justify-center px-4 lg:bottom-8"
	role="status"
	aria-live="polite"
>
	{#if toast.current}
		{@const t = toast.current}
		{#key t.id}
			<div
				class="pointer-events-auto flex max-w-md items-center gap-3 layer py-2 pr-2 pl-4 text-sm"
				transition:fly={{ y: 16, duration: DURATION.overlay }}
				data-testid="toast"
			>
				<span
					class="material-symbols-rounded !text-[20px] {t.tone === 'error'
						? 'text-pink'
						: 'text-green'}"
					aria-hidden="true">{t.tone === 'error' ? 'error' : 'task_alt'}</span
				>
				<span class="flex-1 text-ink">{t.message}</span>
				{#if t.action}
					{@const action = t.action}
					<button
						type="button"
						onclick={() => {
							action.run();
							toast.dismiss(t.id);
						}}
						class="h-9 press rounded-[2px] px-3 font-semibold text-anime-soft hover:bg-white/5"
					>
						{action.label}
					</button>
				{/if}
				<button
					type="button"
					onclick={() => toast.dismiss(t.id)}
					aria-label="Dismiss"
					class="grid h-9 w-9 place-items-center rounded-[2px] text-muted hover:bg-white/5 hover:text-ink"
				>
					<span class="material-symbols-rounded !text-[18px]" aria-hidden="true">close</span>
				</button>
			</div>
		{/key}
	{/if}
</div>
