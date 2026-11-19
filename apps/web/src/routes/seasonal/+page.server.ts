import { fetchSeasonChart } from '#lib/anilist/client.ts';
import { parseSeasonParams, SEASON_NAMES, seasonHref } from '#lib/page-data/season-chart.ts';
import { loadPublic } from '#lib/server/public-load.ts';
import type { PageServerLoad } from './$types';

// The season's signed-out chart, for the first render and search engines.
// The page fetches the viewer's own (18+, list state) in the browser.
export const load: PageServerLoad = async (event) => {
	const now = new Date();
	const { season, year } = parseSeasonParams(event.url.searchParams, now);
	const name = `${SEASON_NAMES[season]} ${year}`;
	const chart = await loadPublic(event, () =>
		fetchSeasonChart(season, year, { signedIn: false, showAdult: false })
	);
	return {
		chart: chart && { season, year, ...chart },
		meta: {
			title: `${name} anime chart`,
			description: chart?.media.length
				? `All ${chart.media.length} anime premiering in ${name}, with what's trending, what's new and when each one airs.`
				: `Every anime premiering in ${name}, with what's trending, what's new and when each one airs.`,
			canonical: seasonHref({ season, year }, now)
		}
	};
};
