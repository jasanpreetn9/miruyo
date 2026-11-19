<script lang="ts">
	import LegalPage from '#lib/components/legal/LegalPage.svelte';
	import { LEGAL } from '#lib/legal.ts';

	// Support: the App Store's support URL points here.

	const { app, email } = LEGAL;
</script>

<LegalPage title="Support">
	{#snippet summary()}
		<p class="m-0">
			<strong class="text-ink">Need help?</strong>
			Email <a href="mailto:{email}">{email}</a> and say whether you're on the website or the iPhone app.
		</p>
	{/snippet}

	<h2 id="about">About {app}</h2>
	<p>
		{app} is an unofficial app for
		<a href="https://anilist.co" target="_blank" rel="noreferrer">AniList</a>: you sign in with your
		AniList account, and your list, scores and progress stay on AniList. {app} isn't made by AniList.
	</p>

	<h2 id="faq">Common questions</h2>
	<h3>How do I sign in?</h3>
	<p>
		Tap Log In and approve {app} on AniList. If you don't have an account, create one on
		<a href="https://anilist.co/signup" target="_blank" rel="noreferrer">anilist.co</a>.
	</p>
	<h3>A change I made isn't on AniList</h3>
	<p>
		Changes made offline (or while AniList is busy) wait on your device and are sent once AniList
		can take them. Open the app with a connection and they'll go through.
	</p>
	<h3>I'm not getting episode alerts</h3>
	<p>
		Turn on <em>Alerts on this phone</em> in the app's Settings, and allow notifications for {app} in
		iOS Settings → Notifications. Alerts cover the next episode of what you're watching, and are refreshed
		each time you open the app.
	</p>
	<h3>How do I delete my data?</h3>
	<p>
		{app} keeps no account of its own. Sign out (or delete the app) to remove what's on your device, revoke
		access in
		<a href="https://anilist.co/settings/apps" target="_blank" rel="noreferrer"
			>AniList's app settings</a
		>, and delete your AniList account on AniList if you want it gone. See the
		<a href="/privacy">Privacy Policy</a> for details.
	</p>

	<h2 id="contact">Contact</h2>
	<p>Email <a href="mailto:{email}">{email}</a>. We usually answer within a few days.</p>
</LegalPage>
