<script lang="ts">
	import LegalPage from '#lib/components/legal/LegalPage.svelte';
	import { LEGAL } from '#lib/legal.ts';

	// Adapted from General Legal's "Website Terms of Use" template (CC0,
	// github.com/General-Legal/legal-templates) for a free, non-commercial
	// front end to AniList. The template's arbitration clause is left out:
	// it needs a mailing address for opt-outs and suits a company more than a
	// personal project. Add it back (Section 11 of the template) if that changes.

	const { app, operator, email, site, governingLaw, venue } = LEGAL;
</script>

<LegalPage title="Terms of Use">
	{#snippet summary()}
		<p class="m-0">
			<strong class="text-ink">The short version:</strong>
			{app} is free, unofficial and provided as is. Your account and list belong to AniList, so AniList's
			terms apply too. Don't misuse the site or AniList through it, and remember that the anime and manga
			shown here belong to their creators.
		</p>
	{/snippet}

	<p>
		The website at {site} (the "<strong>Site</strong>" or "<strong>{app}</strong>") is run by {operator}
		("<strong>we</strong>", "<strong>us</strong>" or "<strong>our</strong>"). These Terms of Use ("<strong
			>Terms</strong
		>") govern your use of the Site. By using the Site, or by logging in with AniList, you agree to
		these Terms. If you don't agree, please don't use the Site.
	</p>

	<h2 id="eligibility">1. Who can use {app}</h2>
	<p>
		You must be at least 13 years old, and old enough to agree to these Terms where you live. If
		you're under 18 (or the age of majority where you live), you need a parent or guardian's
		permission. You must also meet AniList's own age requirements to log in.
	</p>

	<h2 id="anilist">2. Your AniList account</h2>
	<ol>
		<li>
			<strong>Logging in.</strong>
			{app} doesn't have its own accounts. Logging in connects your
			<a href="https://anilist.co" target="_blank" rel="noreferrer">AniList</a> account, and what
			you do in {app} (changing progress, scores, statuses, favourites or settings) is saved to that account.
		</li>
		<li>
			<strong>AniList's terms apply.</strong> Your AniList account, and everything saved to it, is
			also governed by AniList's
			<a href="https://anilist.co/terms" target="_blank" rel="noreferrer">terms of service</a>.
			You're responsible for following them.
		</li>
		<li>
			<strong>Security.</strong> You're responsible for activity on your account, including through {app}.
			Sign out on shared devices, and if you think someone else has access, revoke {app} in
			<a href="https://anilist.co/settings/apps" target="_blank" rel="noreferrer"
				>AniList's app settings</a
			>.
		</li>
		<li>
			<strong>Not affiliated.</strong>
			{app} is an independent project. It isn't made, endorsed or supported by AniList.
		</li>
	</ol>

	<h2 id="use">3. Using the Site</h2>
	<ol>
		<li>
			<strong>Licence.</strong> We give you a limited, personal, non-exclusive, non-transferable and revocable
			licence to use the Site for your own non-commercial purposes, subject to these Terms.
		</li>
		<li>
			<strong>Don't:</strong>
			<ul>
				<li>
					scrape, crawl or make automated requests to the Site, or use it to send excessive or
					automated requests to AniList;
				</li>
				<li>
					interfere with, overload or disrupt the Site, or try to get around its security or rate
					limits;
				</li>
				<li>use the Site to break the law or anyone's rights, or to break AniList's terms;</li>
				<li>
					sell, rent or commercially exploit the Site, or pretend to be us or to be affiliated with
					us; or
				</li>
				<li>access another person's AniList account without their permission.</li>
			</ul>
		</li>
		<li>
			<strong>Changes.</strong> The Site is a free project. We may change, pause or stop it, in whole
			or in part, at any time and without notice, and we don't have to provide support.
		</li>
	</ol>

	<h2 id="content">4. Content and ownership</h2>
	<ol>
		<li>
			<strong>Titles and artwork.</strong> Information about anime, manga, characters and staff, and
			the cover art, banners and trailers shown on the Site, come from AniList and other third
			parties. They belong to their respective creators and rights holders and are shown for
			identification and reference. {app} doesn't host or stream any anime or manga.
		</li>
		<li>
			<strong>Adult content.</strong> Titles marked as adult (18+) are hidden unless you turn them on
			in Settings, which saves the choice to your AniList account. By turning them on, you confirm you're
			an adult and that viewing them is legal where you are.
		</li>
		<li>
			<strong>The Site.</strong> The design, code and text of {app} itself belong to {operator}.
			Nothing in these Terms gives you ownership of them.
		</li>
		<li>
			<strong>Your data.</strong> What you save to AniList is yours and AniList's, as its terms describe.
			We don't claim any rights to it.
		</li>
		<li>
			<strong>Feedback.</strong> If you send us suggestions or feedback, we may use them freely and without
			paying or crediting you.
		</li>
		<li>
			<strong>Copyright complaints.</strong> If you believe something on the Site infringes your
			copyright, email <a href="mailto:{email}">{email}</a> with the work, where it appears on the Site,
			your contact details, and a statement that you're the owner or authorised to act for them. Content
			that comes from AniList is best reported to AniList as well.
		</li>
	</ol>

	<h2 id="privacy">5. Privacy</h2>
	<p>
		How personal information is handled is described in our <a href="/privacy">Privacy Policy</a>,
		and what's stored on your device in <a href="/cookies">Cookies &amp; Storage</a>. Both are part
		of these Terms.
	</p>

	<h2 id="third-parties">6. Third-party services</h2>
	<p>
		The Site relies on and links to services we don't control, including AniList, YouTube and
		Dailymotion. We aren't responsible for them, and their own terms and privacy policies apply when
		you use them. If AniList is unavailable, changes its API or limits access, parts of {app} may stop
		working.
	</p>

	<h2 id="disclaimers">7. Disclaimers</h2>
	<p class="caps">
		THE SITE IS PROVIDED "AS IS" AND "AS AVAILABLE", WITHOUT WARRANTIES OF ANY KIND. TO THE FULLEST
		EXTENT THE LAW ALLOWS, WE DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
		MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. WE DON'T PROMISE
		THAT THE SITE WILL BE UNINTERRUPTED, ERROR-FREE OR SECURE, THAT INFORMATION ON IT (SUCH AS
		AIRING TIMES) IS ACCURATE, OR THAT CHANGES WILL BE SAVED TO ANILIST.
	</p>

	<h2 id="liability">8. Limitation of liability</h2>
	<p class="caps">
		TO THE FULLEST EXTENT THE LAW ALLOWS: (A) WE WON'T BE LIABLE FOR ANY INDIRECT, INCIDENTAL,
		SPECIAL, CONSEQUENTIAL OR PUNITIVE DAMAGES, OR FOR LOST DATA OR PROFITS, ARISING FROM YOUR USE
		OF (OR INABILITY TO USE) THE SITE; AND (B) OUR TOTAL LIABILITY FOR ANY CLAIM RELATING TO THE
		SITE IS LIMITED TO $50 USD.
	</p>
	<p>
		Some places don't allow these exclusions or limits, so some of them may not apply to you.
		Nothing in these Terms limits rights you have as a consumer that can't be waived by contract.
	</p>

	<h2 id="indemnity">9. Indemnity</h2>
	<p>
		To the extent the law allows, you agree to cover our reasonable costs, including legal fees,
		from claims by others that arise from your misuse of the Site or your breach of these Terms.
	</p>

	<h2 id="termination">10. Ending your use</h2>
	<p>
		You can stop using {app} at any time: sign out, and revoke access in AniList's app settings. We may
		suspend or end your access if you break these Terms or misuse the Site. Sections 4 to 12 continue
		to apply after that.
	</p>

	<h2 id="law">11. Governing law</h2>
	<p>
		These Terms are governed by the laws of {governingLaw}, without regard to its conflict-of-law
		rules. Disputes will be heard in the state and federal courts in {venue}, except that either of
		us may bring an individual claim in small claims court. If you're a consumer in Europe or
		elsewhere, you also keep the protection of the mandatory laws of the country you live in, and
		may bring claims in its courts.
	</p>

	<h2 id="general">12. General</h2>
	<ol>
		<li>
			<strong>Changes to these Terms.</strong> We may update these Terms. We'll change the "Last
			updated" date above, and for significant changes we'll say so on the site. Using {app} after an
			update means you accept the new Terms.
		</li>
		<li>
			<strong>Whole agreement.</strong> These Terms, with the Privacy Policy and Cookies &amp; Storage,
			are the whole agreement between you and us about the Site. If part of them can't be enforced, the
			rest still applies. Not enforcing a term isn't a waiver of it. You may not transfer these Terms;
			we may transfer them to someone who takes over the Site.
		</li>
		<li>
			<strong>Accessibility.</strong> We aim to meet the Web Content Accessibility Guidelines (WCAG)
			2.1, Level AA. If something is hard to use, tell us at
			<a href="mailto:{email}">{email}</a>.
		</li>
		<li>
			<strong>California users.</strong> Under California Civil Code Section 1789.3, you may contact the
			Complaint Assistance Unit of the Division of Consumer Services of the California Department of Consumer
			Affairs at 1625 N. Market Blvd., Suite N112, Sacramento, CA 95834, or (800) 952-5210. The Site is
			free to use.
		</li>
		<li>
			<strong>Contact.</strong> Questions about these Terms go to
			<a href="mailto:{email}">{email}</a>.
		</li>
	</ol>
</LegalPage>
