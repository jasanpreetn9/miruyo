import { fetchAiringWeek } from '#lib/anilist/client.ts';
import { addDays, parseWeekParam, toWeekParam } from '#lib/page-data/seasonal.ts';
import { parseSeasonParams, SEASON_NAMES } from '#lib/page-data/season-chart.ts';
import { loadPublic } from '#lib/server/public-load.ts';
import type { PageMeta } from '#lib/seo.ts';
import type { PageServerLoad } from './$types';

// The week's signed-out airings, for the first render and search engines.
// The week is the server's (UTC); the page fetches the viewer's own week, in
// their timezone, in the browser.
export const load: PageServerLoad = async (event) => {
	const week = event.url.searchParams.get('week');
	const monday = parseWeekParam(week, new Date());
	const start = Math.floor(monday.getTime() / 1000);
	const end = Math.floor(addDays(monday, 7).getTime() / 1000);
	const slots = await loadPublic(event, () =>
		fetchAiringWeek(start, end, { signedIn: false, showAdult: false })
	);
	const { season, year } = parseSeasonParams(new URLSearchParams(), monday);
	return {
		week: slots && { start, slots },
		meta: {
			headline: `${SEASON_NAMES[season]} ${year} Anime Schedule: Episode Release Times`,
			canonical: week ? `/schedule?week=${toWeekParam(monday)}` : '/schedule'
		} satisfies PageMeta
	};
};
