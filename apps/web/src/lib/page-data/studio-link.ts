// Where a studio opens in miruyo: its own page (routes/studio/[id]). Kept
// apart from studio.ts so the title page's data can link to it without
// importing the studio page's.

export const studioHref = (id: number) => `/studio/${id}`;
