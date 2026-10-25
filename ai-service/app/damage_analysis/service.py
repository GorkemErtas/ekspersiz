from .images import prepare
from .provider import GeminiVisionProvider, Settings, VisionUnavailable
from .schemas import AnalysisResponse, Recommendation

DISCLAIMER = 'Bu değerlendirme yalnızca iki fotoğraftaki görünür bulgulara dayanır; fiziksel ekspertiz yerine geçmez.'


class DamageAnalysisService:
    def require_available(self):
        try:
            return Settings.from_env()
        except (ValueError, TypeError) as exc:
            raise VisionUnavailable('Görsel analiz yapılandırması geçersiz.') from exc

    def status(self):
        try:
            self.require_available()
            return 'READY'
        except VisionUnavailable:
            return 'UNAVAILABLE'

    def analyze(self, detail, overview, vehicle_region=None, detail_type=None, overview_type=None):
        settings = self.require_available()
        close = prepare(detail, detail_type)
        general = prepare(overview, overview_type)
        if close.fingerprint == general.fingerprint:
            raise ValueError('Genel görünüm ve yakın detay için iki farklı fotoğraf yükleyin.')
        result = GeminiVisionProvider(settings).analyze(general, close, vehicle_region)
        recommendations = [Recommendation(damageType=f.damageType, recommendedAction=f.recommendedAction,
                           affectedParts=[] if f.affectedPart == 'UNKNOWN' else [f.affectedPart]) for f in result.visualFindings]
        return AnalysisResponse(**result.model_dump(exclude={'analysisMessage'}),
                                analysisMessage=(result.analysisMessage + ' ' + DISCLAIMER)[:1000],
                                modelVersion=settings.model,
                                damageTypes=list(dict.fromkeys(f.damageType for f in result.visualFindings)),
                                affectedParts=list(dict.fromkeys(f.affectedPart for f in result.visualFindings if f.affectedPart != 'UNKNOWN')),
                                repairRecommendations=recommendations)
