import type { TitleLanguage } from './types.ts';

/** The languages a picker offers; the _STYLISED variants are a separate toggle. */
export type BaseTitleLanguage = 'ROMAJI' | 'ENGLISH' | 'NATIVE';

export const TITLE_LANGUAGES: { key: BaseTitleLanguage; name: string; example: string }[] = [
	{ key: 'ROMAJI', name: 'Romaji', example: 'Kusuriya no Hitorigoto' },
	{ key: 'ENGLISH', name: 'English', example: 'The Apothecary Diaries' },
	{ key: 'NATIVE', name: 'Native', example: '薬屋のひとりごと' }
];

/** ROMAJI_STYLISED → ROMAJI: the picker only offers the base languages. */
export function baseTitleLanguage(lang: TitleLanguage | undefined): BaseTitleLanguage {
	if (lang?.startsWith('ENGLISH')) return 'ENGLISH';
	if (lang?.startsWith('NATIVE')) return 'NATIVE';
	return 'ROMAJI';
}
