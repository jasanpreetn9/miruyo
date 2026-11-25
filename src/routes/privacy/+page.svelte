<script lang="ts">
	import LegalPage from '#lib/components/legal/LegalPage.svelte';
	import { LEGAL } from '#lib/legal.ts';

	// Adapted from General Legal's "Privacy Policy (GDPR Enhanced)" template
	// (CC0, github.com/General-Legal/legal-templates), cut down to what Miruyo
	// actually does: no servers of its own holding user data, no cookies, no
	// ads, and only anonymous page counts and speed measurements (Cloudflare,
	// see src/lib/untracked.ts). Keep it in
	// step with the app — a new tracker,
	// store or third party means a new paragraph here and on /cookies.

	const { app, operator, email } = LEGAL;
</script>

<LegalPage title="Privacy Policy">
	{#snippet summary()}
		<p class="m-0">
			<strong class="text-ink">The short version:</strong>
			{app} is a front end for your AniList account. Your list lives on AniList, and your browser talks
			to AniList directly. We don't run a database of users, we don't use cookies or ads, our only analytics
			are anonymous page counts, and we never sell your information.
		</p>
	{/snippet}

	<p>
		{app} ("<strong>{app}</strong>", "<strong>we</strong>", "<strong>us</strong>" or "<strong
			>our</strong
		>") is a website and an iPhone app for tracking anime and manga with an
		<a href="https://anilist.co" target="_blank" rel="noreferrer">AniList</a> account. It is run by
		{operator}. This Privacy Policy explains what personal information is involved when you use {app},
		where it goes, and the choices you have. It applies to the {app} website, the {app} iPhone app, and
		anything that links to this policy (the "<strong>Service</strong>").
	</p>
	<p>
		If you're in the European Economic Area or the United Kingdom, see
		<a href="#europe">Notice to European users</a>. If you live in a U.S. state with a privacy law,
		see <a href="#us-states">U.S. state privacy rights</a>.
	</p>

	<h2 id="collect">Personal information we handle</h2>

	<h3>Your AniList account</h3>
	<p>
		{app} has no accounts of its own. When you choose <strong>Log in with AniList</strong>, you
		approve access on anilist.co and AniList sends your browser an access token. With that token,
		your browser reads from and writes to AniList on your behalf:
	</p>
	<ul>
		<li>
			<strong>Profile data</strong>: your AniList username, avatar, banner, favourites and account
			settings (title language, score format, adult-content and notification preferences).
		</li>
		<li>
			<strong>List data</strong>: the titles on your anime and manga lists, with their status,
			progress, scores, dates, repeats and notes.
		</li>
		<li><strong>Notifications</strong> that AniList has for your account, such as new episodes.</li>
	</ul>
	<p>
		These requests go from your browser straight to AniList's API (<code>graphql.anilist.co</code>).
		They don't pass through or get stored on any server of ours. {app} never sees your AniList password.
	</p>

	<h3>Information stored on your device</h3>
	<p>
		{app} keeps a few things in your browser's local storage so it works the way you left it: your AniList
		access token, whether you're looking at anime or manga, your My List layout, the first-run setup,
		and titles you've hidden from For You. They stay on your device and are never sent to us. The full
		list is on the <a href="/cookies">Cookies &amp; Storage</a> page.
	</p>

	<h3>The iPhone app</h3>
	<p>
		The app works the same way as the website: it talks to AniList directly, and there's no {app} server
		in between.
	</p>
	<ul>
		<li>
			<strong>Sign-in</strong>: your AniList access token is kept in the iOS Keychain on your phone.
		</li>
		<li>
			<strong>A copy of your list and Home</strong> is kept on the phone so the app works offline, and
			changes you make offline wait there until AniList can take them.
		</li>
		<li>
			<strong>Preferences</strong> (anime or manga, list layout, titles hidden from For You, setup choices)
			are kept in the app's own storage.
		</li>
		<li>
			<strong>Episode alerts</strong>, if you turn them on, are scheduled by iOS on your phone from
			AniList's airing times. Nothing about them is sent to us, and they don't use a push service.
		</li>
		<li>
			The app has <strong>no analytics, ads, tracking or crash-reporting SDKs</strong>. If you
			choose to share analytics with app developers in iOS Settings, Apple may pass us anonymous
			crash reports and usage figures; that's Apple's processing, under Apple's privacy policy.
		</li>
	</ul>
	<p>
		All of this stays on your phone and is never sent to us. Signing out removes the token and the
		copy of your list; deleting the app removes everything.
	</p>

	<h3>Information collected automatically</h3>
	<p>When your browser loads {app}, a few services see the request, as with any website:</p>
	<ul>
		<li>
			<strong>Our host, Cloudflare</strong>, serves the site and keeps short-lived request logs that
			may include your IP address, browser type, the page requested and the time. We use these only
			to keep the site running and secure.
		</li>
		<li>
			<strong>Cloudflare Web Analytics</strong> counts page views and measures how fast pages load: for
			each visit it records the page, the site you came from, your country, and your device and browser.
			It doesn't use cookies or fingerprint your browser, and it never runs on the sign-in page, whose
			address carries your AniList access token. It runs only on the website, not in the iPhone app.
		</li>
		<li>
			<strong>Google Fonts</strong> serves the site's typefaces, so Google receives your IP address and
			browser details when the fonts load.
		</li>
		<li>
			<strong>AniList</strong> serves the cover art and banners, and <strong>YouTube</strong> serves trailer
			thumbnails, so they receive your IP address and browser details when those images load.
		</li>
	</ul>
	<p>
		Apart from those page counts and speed measurements, we don't use analytics, advertising,
		session-replay or any other tracking tools.
	</p>

	<h3>Information you send us</h3>
	<p>
		If you email us, we'll have your email address and whatever you include in the message. We use
		it only to reply and to deal with your request.
	</p>

	<h2 id="use">How we use personal information</h2>
	<ul>
		<li>
			<strong>To provide the Service</strong>: showing your list, progress, stats, recommendations
			and notifications, and saving the changes you make to AniList.
		</li>
		<li>
			<strong>To remember your preferences</strong> on your device, such as anime or manga mode and your
			list layout.
		</li>
		<li>
			<strong>To keep the Service secure and working</strong>: hosting logs help us find errors and
			stop abuse.
		</li>
		<li>
			<strong>To improve the Service</strong>: anonymous page counts show which pages get used, and
			speed measurements show which load slowly.
		</li>
		<li><strong>To answer you</strong> when you contact us.</li>
		<li>
			<strong>To comply with the law</strong> and protect our rights, yours and other people's, such as
			responding to lawful requests from authorities.
		</li>
	</ul>
	<p>
		For You picks are worked out in your browser from your own list and scores. They aren't sent
		anywhere and aren't used for anything else.
	</p>

	<h2 id="share">How personal information is shared</h2>
	<p>We don't sell personal information and we don't share it for advertising. It reaches:</p>
	<ul>
		<li>
			<strong>AniList</strong>, because that's where your account and list live and you've asked
			{app} to use them. AniList's handling of your data is covered by the
			<a href="https://anilist.co/terms" target="_blank" rel="noreferrer"
				>AniList terms and privacy policy</a
			>.
		</li>
		<li>
			<strong>Service providers</strong> that help run the site: Cloudflare (hosting, page counts and
			speed measurements) and Google (fonts). YouTube serves trailer thumbnails, and trailer links open
			on YouTube or Dailymotion, whose own policies apply there.
		</li>
		<li>
			<strong>Authorities and others</strong>, if we believe in good faith that the law requires it
			or that it's needed to protect rights, property or safety.
		</li>
		<li>
			<strong>A successor</strong>, if {app} is ever transferred to someone else, who would have to treat
			your information as this policy describes.
		</li>
	</ul>

	<h2 id="retention">How long we keep it</h2>
	<ul>
		<li>
			Data in your browser stays until you sign out (which removes the access token) or clear the
			site's data in your browser.
		</li>
		<li>Data in the iPhone app stays until you sign out or delete the app.</li>
		<li>Cloudflare keeps request logs for a short period under its own retention settings.</li>
		<li>Emails are kept as long as needed to deal with what you asked, then deleted.</li>
		<li>
			Your AniList data is kept by AniList until you change or delete it there. {app} doesn't keep a copy.
		</li>
	</ul>

	<h2 id="choices">Your choices</h2>
	<ul>
		<li>
			<strong>Sign out</strong> from Settings to remove the access token from this browser.
		</li>
		<li>
			<strong>Revoke access</strong> at any time in
			<a href="https://anilist.co/settings/apps" target="_blank" rel="noreferrer"
				>AniList's app settings</a
			>. {app} then can't read or change your account.
		</li>
		<li>
			<strong>Change or delete your list and profile</strong> in {app} or on AniList. Deleting your AniList
			account is done on AniList.
		</li>
		<li>
			<strong>Clear stored preferences</strong> by clearing this site's data in your browser settings,
			or by deleting the iPhone app.
		</li>
		<li>
			<strong>Turn episode alerts off</strong> in the app's Settings, or in iOS Settings → Notifications.
		</li>
		<li>
			<strong>Use {app} without signing in</strong>. Browse, search, the season chart and title
			pages all work signed out.
		</li>
		<li>
			<strong>Do Not Track and Global Privacy Control.</strong> We don't track you across sites or sell
			or share your information for advertising, so there's nothing for these signals to turn off.
		</li>
	</ul>

	<h2 id="other-sites">Other sites</h2>
	<p>
		{app} links to AniList, YouTube, Dailymotion and other sites we don't control. Their own privacy policies
		apply when you visit them.
	</p>

	<h2 id="security">Security</h2>
	<p>
		The site is served only over HTTPS, and the access token is removed from the address bar as soon
		as you sign in. Your token is kept in your browser's local storage, so anyone with access to
		your browser profile could use it. Sign out on shared devices. No system is completely secure,
		and we can't guarantee the security of information sent over the internet.
	</p>

	<h2 id="transfer">International transfers</h2>
	<p>
		{app} is run from the United States, and our service providers and AniList may process information
		in the United States and other countries whose privacy laws may be less protective than where you
		live.
	</p>

	<h2 id="children">Children</h2>
	<p>
		{app} isn't meant for children under 13, and in the EEA and UK it isn't meant for anyone under 16
		(or a lower age set by your country's law). We don't knowingly collect personal information from children.
		If you believe a child has used {app}, contact us and we'll help remove what we can.
	</p>

	<h2 id="changes">Changes to this policy</h2>
	<p>
		We may update this policy. When we do, we'll change the "Last updated" date above, and for
		significant changes we'll say so on the site. Continuing to use {app} after an update means the new
		policy applies.
	</p>

	<h2 id="contact">Contact us</h2>
	<p>
		For questions, or to exercise any privacy right below, email
		<a href="mailto:{email}">{email}</a>.
	</p>

	<h2 id="us-states">U.S. state privacy rights</h2>
	<p>
		Residents of some U.S. states, including California, Colorado, Connecticut, Virginia, Texas,
		Oregon and others, have rights under their state's privacy law. Depending on where you live, you
		may ask us to:
	</p>
	<ul>
		<li>tell you what personal information we've collected about you, and give you a copy;</li>
		<li>correct or delete it; and</li>
		<li>reconsider a request we've turned down (an appeal).</li>
	</ul>
	<p>
		We don't sell personal information, share it for targeted advertising, use it for profiling with
		legal or similarly significant effects, or knowingly collect it from anyone under 16. We don't
		collect sensitive personal information. We won't treat you differently for using your rights.
	</p>
	<p>
		Because we don't keep your AniList data, most requests are answered quickest on AniList or with
		the choices above. Otherwise, email <a href="mailto:{email}">{email}</a>. We may ask for details
		to confirm the request is yours. You can use an authorized agent; we may ask for proof that they
		act for you.
	</p>
	<p>
		<strong>Information practices over the last 12 months.</strong> This table uses the categories in
		the California Consumer Privacy Act.
	</p>
	<div class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>What we handle</th>
					<th>CCPA category</th>
					<th>Why</th>
					<th>Disclosed to</th>
					<th>Sold or shared</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td>AniList username, avatar, favourites, settings</td>
					<td>Identifiers; Profile information</td>
					<td>Providing the Service</td>
					<td>AniList (at your direction)</td>
					<td>No</td>
				</tr>
				<tr>
					<td>Anime and manga list, scores, progress</td>
					<td>Commercial information (consumption history)</td>
					<td>Providing the Service</td>
					<td>AniList (at your direction)</td>
					<td>No</td>
				</tr>
				<tr>
					<td>IP address, browser details, pages requested</td>
					<td>Identifiers; Internet activity</td>
					<td>Running and securing the Service</td>
					<td>Hosting and font providers</td>
					<td>No</td>
				</tr>
				<tr>
					<td>Email and message contents</td>
					<td>Identifiers</td>
					<td>Replying to you</td>
					<td>Email provider</td>
					<td>No</td>
				</tr>
			</tbody>
		</table>
	</div>
	<p>
		<strong>California "Shine the Light".</strong> We don't share personal information with third parties
		for their own direct marketing.
	</p>
	<p>
		<strong>Nevada.</strong> We don't sell covered information. You can still ask us not to by
		emailing
		<a href="mailto:{email}">{email}</a>.
	</p>

	<h2 id="europe">Notice to European users</h2>
	<p>
		This section applies to people in the European Economic Area and the United Kingdom ("<strong
			>Europe</strong
		>"). Here "personal information" means "personal data" as the GDPR and UK GDPR define it.
	</p>
	<p>
		<strong>Controller.</strong>
		{operator} is the controller of the personal data described in this policy, and can be reached at
		<a href="mailto:{email}">{email}</a>. AniList is a separate controller of your AniList account
		data.
	</p>
	<h3>Legal bases</h3>
	<div class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>Purpose</th>
					<th>Data</th>
					<th>Legal basis</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td>Providing the Service when you sign in</td>
					<td>AniList profile and list data, access token</td>
					<td>Contractual necessity: it's what you asked {app} to do</td>
				</tr>
				<tr>
					<td>Remembering your preferences on your device</td>
					<td>Local storage values</td>
					<td>
						Contractual necessity; storage that's strictly necessary for a feature you asked for
						doesn't need consent
					</td>
				</tr>
				<tr>
					<td>Hosting, security and fonts</td>
					<td>IP address, browser details, request logs</td>
					<td>Legitimate interests in delivering a working, secure website</td>
				</tr>
				<tr>
					<td>Counting page views and measuring speed</td>
					<td>Page address (without its query), referring site, country, device and browser</td>
					<td>Legitimate interests in knowing which pages are used and keeping them fast</td>
				</tr>
				<tr>
					<td>Answering you</td>
					<td>Email and message</td>
					<td>Legitimate interests in responding to people who contact us</td>
				</tr>
				<tr>
					<td>Compliance and protection</td>
					<td>Any of the above, as needed</td>
					<td>Compliance with law; legitimate interests in protecting rights and safety</td>
				</tr>
			</tbody>
		</table>
	</div>
	<p>
		We don't make automated decisions with legal or similarly significant effects. Please don't send
		us sensitive data (such as health, religion or political opinions).
	</p>
	<h3>Your rights</h3>
	<p>
		You can ask us to give you access to your personal data, correct it, delete it, restrict or
		object to how we use it, or send it to you or someone else in a portable format. Email
		<a href="mailto:{email}">{email}</a>. If we turn a request down, we'll tell you why. You can
		also complain to the data protection authority where you live: in the EEA, find it through the
		<a
			href="https://edpb.europa.eu/about-edpb/about-edpb/members_en"
			target="_blank"
			rel="noreferrer">European Data Protection Board</a
		>; in the UK, the
		<a href="https://ico.org.uk" target="_blank" rel="noreferrer"
			>Information Commissioner's Office</a
		>.
	</p>
	<h3>Transfers outside Europe</h3>
	<p>
		{app} is run from the United States, and our providers process data there and elsewhere. Where a country
		doesn't have an adequacy decision, we rely on safeguards such as the European Commission's standard
		contractual clauses (which our providers offer) or, where that's not available, on the transfer being
		necessary to provide the Service you asked for. Contact us for details.
	</p>
</LegalPage>
