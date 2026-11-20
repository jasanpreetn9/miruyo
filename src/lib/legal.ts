// Who runs the site, for the Privacy Policy, Terms and Cookies pages. Every
// legal page reads from here, so a change of name, address or contact is one
// edit.

export const LEGAL = {
	/** The app's name as the documents use it. */
	app: 'Miruyo',
	/** The person (or company) that runs the site and is responsible for it. */
	operator: 'jnagra.com',
	/** Where people send privacy requests, questions and notices. */
	email: 'help@jnagra.com',
	/** The site's public address. */
	site: 'miruyo.jnagra.com',
	/** Whose law governs the Terms ("the laws of …"). */
	governingLaw: 'the State of Texas',
	/** Where disputes are heard ("the courts in …"); a county can narrow it. */
	venue: 'Texas',
	/** The iOS app's App Store page; the footer shows a link once it's set. */
	appStore: null as string | null,
	/** When the documents last changed; bump it with every edit. */
	updated: 'November 9, 2026'
} as const;

export const LEGAL_PAGES = [
	{ href: '/privacy', label: 'Privacy Policy' },
	{ href: '/terms', label: 'Terms of Use' },
	{ href: '/cookies', label: 'Cookies & Storage' },
	{ href: '/support', label: 'Support' }
] as const;
