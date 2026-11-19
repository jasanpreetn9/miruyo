import { describe, expect, it } from 'vitest';
import { baseTitleLanguage } from './title-language.ts';

describe('baseTitleLanguage', () => {
	it('drops the _STYLISED variant', () => {
		expect(baseTitleLanguage('ENGLISH_STYLISED')).toBe('ENGLISH');
		expect(baseTitleLanguage('NATIVE_STYLISED')).toBe('NATIVE');
		expect(baseTitleLanguage('ROMAJI_STYLISED')).toBe('ROMAJI');
	});

	it('defaults to Romaji', () => {
		expect(baseTitleLanguage(undefined)).toBe('ROMAJI');
	});
});
