import fixture from '../../../visual/fixtures.json';
import type { Inspection } from '../../core/models';
import { reportContent } from './reportContent';
const inspection = fixture.inspection as Inspection;
test('inspection-only schema never labels its estimate as a repair quote', () =>
  expect(reportContent(inspection).priceTitle).toBe(
    'Tahmini Fiziksel İnceleme Maliyeti',
  ));
test('historical inventories do not invent damage-to-part relationships', () => {
  const content = reportContent({
    ...inspection,
    visualFindings: [],
    repairRecommendations: [],
    damageTypes: ['SCRATCH', 'DENT'],
    affectedParts: ['HOOD', 'REAR_DOOR'],
  });
  expect(content.findings).toHaveLength(1);
  expect(content.findings[0]?.damageTypes).toHaveLength(2);
  expect(content.findings[0]?.part).toContain('Kaput');
});
test('no-visible-damage reports suppress stale model findings and invalid estimates', () => {
  const content = reportContent({
    ...inspection,
    damageSeverity: 'NONE',
    report: {
      ...inspection.report!,
      estimatedMinimumPrice: 0,
      estimatedMaximumPrice: 0,
    },
  });
  expect(content.findings).toEqual([]);
  expect(content.price).toBe('Maliyet hesaplanmadı');
});
test('inconclusive outcomes keep photo guidance and safety narratives', () => {
  const message = 'Gizli mekanik hasar bu fotoğraftan dışlanamaz.';
  const content = reportContent({
    ...inspection,
    analysisOutcome: 'INCONCLUSIVE',
    report: {
      ...inspection.report!,
      summary: message,
      damageDescription: message,
      repairRecommendation: 'Fiziksel inceleme gereklidir.',
    },
  });
  expect(content.title).toBe('Sonuç Belirsiz');
  expect(content.narrative.filter((value) => value === message)).toHaveLength(
    1,
  );
  expect(content.disclaimer).toContain('ekspertiz');
});
