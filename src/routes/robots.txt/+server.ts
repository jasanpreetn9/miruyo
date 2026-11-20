import { SITE_URL } from '#lib/seo.ts';
import type { RequestHandler } from './$types';

// Built once at deploy time, so the sitemap line follows PUBLIC_SITE_URL.
export const prerender = true;

const RULES = `# Search engines may crawl titles and the site's own pages. Everything else
# links onward into most of AniList, which costs a request per page for very
# little search traffic, so crawlers stay out of it. Personal pages also opt
# out with a noindex tag.
User-agent: *
Disallow: /browse?
Disallow: /search
Disallow: /character/
Disallow: /staff/
Disallow: /studio/
Disallow: /user/
Disallow: /api/

# AI crawlers and scrapers: they fetch fast, ignore crawl limits and send no
# visitors.
User-agent: GPTBot
User-agent: ChatGPT-User
User-agent: OAI-SearchBot
User-agent: ClaudeBot
User-agent: Claude-User
User-agent: Claude-SearchBot
User-agent: anthropic-ai
User-agent: CCBot
User-agent: Google-Extended
User-agent: Applebot-Extended
User-agent: Bytespider
User-agent: Amazonbot
User-agent: meta-externalagent
User-agent: FacebookBot
User-agent: PerplexityBot
User-agent: Perplexity-User
User-agent: cohere-ai
User-agent: Diffbot
User-agent: ImagesiftBot
User-agent: Timpibot
User-agent: omgili
User-agent: PetalBot
User-agent: AhrefsBot
User-agent: SemrushBot
User-agent: MJ12bot
User-agent: DotBot
Disallow: /
`;

export const GET: RequestHandler = () =>
	new Response(
		`${RULES}
Sitemap: ${SITE_URL}/sitemap.xml
`,
		{ headers: { 'Content-Type': 'text/plain' } }
	);
