import copy
import io
import json
import os
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError, URLError

from fastapi import FastAPI
from PIL import Image
from pydantic import ValidationError
from app.damage_analysis import api
from app.damage_analysis.images import prepare
from app.damage_analysis.provider import GeminiVisionProvider, ProviderError, Settings
from app.damage_analysis.schemas import GeminiAnalysis
from app.service_security import ServiceSecurityMiddleware

KEY = 'test-internal-service-secret-32-characters'


def photo(seed=0, fmt='PNG'):
    image = Image.new('RGB', (320, 320))
    image.putdata([((x+seed) % 256, (y*2+seed) % 256, (x+y) % 256)
                   for y in range(320) for x in range(320)])
    output = io.BytesIO()
    image.save(output, format=fmt)
    return output.getvalue()


def success():
    return {'analysisOutcome': 'DAMAGE_DETECTED', 'damageSeverity': 'MINOR',
            'photoAssessment': {'overviewUsable': True, 'detailUsable': True, 'sameVehicleAndArea': True},
            'visualFindings': [{'damageType': 'SCRATCH', 'affectedPart': 'FRONT_DOOR', 'severity': 'MINOR',
                'description': 'Kapı yüzeyinde çizik görünümü izleniyor.', 'recommendedAction': 'POLISHING',
                'repairNotes': 'Polisaj uygunluğu fiziksel incelemeyle değerlendirilebilir.',
                'replacementAssessment': 'UNDETERMINED', 'evidenceImages': ['OVERVIEW', 'DETAIL']}],
            'analysisMessage': 'İki fotoğrafta kapı yüzeyinde çizik görünümü mevcut.', 'additionalPhotoGuidance': ''}


def envelope(value=None, reason='STOP'):
    return json.dumps({'candidates': [{'finishReason': reason, 'content': {'parts': [
        {'text': json.dumps(value if value is not None else success())}]}}],
        'usageMetadata': {'promptTokenCount': 1200, 'candidatesTokenCount': 200,
                          'thoughtsTokenCount': 100}}).encode()


class ProviderTests(unittest.TestCase):
    def test_one_request_contains_both_roles_native_schema_and_no_key_in_url(self):
        response = Mock()
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        response.read.return_value = envelope()
        opener = Mock(return_value=response)
        provider = GeminiVisionProvider(Settings('private-api-secret'), opener=opener)
        image = prepare(photo())
        with self.assertLogs('app.damage_analysis.provider') as logs:
            result = provider.analyze(image, prepare(photo(17)))
        self.assertEqual('DAMAGE_DETECTED', result.analysisOutcome)
        opener.assert_called_once()
        sent = opener.call_args.args[0]
        payload = json.loads(sent.data)
        self.assertNotIn('private-api-secret', sent.full_url)
        self.assertEqual('private-api-secret', sent.get_header('X-goog-api-key'))
        self.assertEqual(['OVERVIEW', 'DETAIL'], [p['text'] for p in payload['contents'][0]['parts'] if 'text' in p])
        self.assertEqual(2, sum('inlineData' in p for p in payload['contents'][0]['parts']))
        schema = payload['generationConfig']['responseJsonSchema']
        self.assertFalse(schema['additionalProperties'])
        self.assertIn('visualFindings', schema['required'])
        self.assertIn('estimated_usd=', ''.join(logs.output))
        self.assertNotIn('private-api-secret', ''.join(logs.output))

    def test_timeout_and_invalid_json_are_not_retried(self):
        for problem in (TimeoutError(), URLError('offline')):
            opener = Mock(side_effect=problem)
            with self.assertRaises(ProviderError):
                GeminiVisionProvider(Settings('key'), opener=opener).analyze(prepare(photo()), prepare(photo(1)))
            self.assertEqual(1, opener.call_count)

    def test_only_explicit_rate_limit_rejection_has_one_bounded_retry(self):
        opener = Mock(side_effect=HTTPError('https://example.invalid', 429, 'rate limited', {}, None))
        sleeper = Mock()
        with self.assertRaises(ProviderError):
            GeminiVisionProvider(Settings('key'), opener=opener, sleeper=sleeper).analyze(prepare(photo()), prepare(photo(1)))
        self.assertEqual(2, opener.call_count)
        sleeper.assert_called_once_with(1)

    def test_unknown_severity_is_preserved(self):
        value = success()
        value['visualFindings'][0]['severity'] = 'UNKNOWN'
        value['damageSeverity'] = 'UNKNOWN'
        self.assertEqual('UNKNOWN', GeminiAnalysis.model_validate(value).damageSeverity)
        value['damageSeverity'] = 'MINOR'
        with self.assertRaises(ValidationError):
            GeminiAnalysis.model_validate(value)

    def test_invalid_enums_confidence_mismatched_photos_and_replacement_claims_rejected(self):
        cases = []
        for field, bad in [('damageType', 'ALIEN_DAMAGE'), ('affectedPart', 'ENGINE'), ('confidence', .99), ('partReplacementRequired', True)]:
            value = success()
            value['visualFindings'][0][field] = bad
            cases.append(value)
        value = success(); value['photoAssessment']['sameVehicleAndArea'] = False; cases.append(value)
        value = success(); value['visualFindings'] *= 2; cases.append(value)
        for value in cases:
            with self.assertRaises(ValidationError):
                GeminiAnalysis.model_validate(value)

    def test_blocked_truncated_and_malformed_provider_replies_fail_safely(self):
        for body in (envelope(reason='MAX_TOKENS'), envelope(reason='SAFETY'), b'not json', b'{"candidates":[],"candidates":[]}'):
            response = Mock(); response.__enter__ = Mock(return_value=response); response.__exit__ = Mock(return_value=False)
            response.read.return_value = body
            opener = Mock(return_value=response)
            with self.assertRaises(ProviderError):
                GeminiVisionProvider(Settings('key'), opener=opener).analyze(prepare(photo()), prepare(photo(1)))
            self.assertEqual(1, opener.call_count)


async def call(app, images, authenticated=True, content_length=None):
    boundary = 'test-photo-boundary'
    pieces = []
    for name, content, mime in images:
        pieces.extend([f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="photo.png"\r\nContent-Type: {mime}\r\n\r\n'.encode(), content, b'\r\n'])
    pieces.append(f'--{boundary}--\r\n'.encode())
    body = b''.join(pieces)
    headers = [(b'content-type', f'multipart/form-data; boundary={boundary}'.encode())]
    if authenticated:
        headers.append((b'x-ai-service-key', KEY.encode()))
    headers.append((b'content-length', str(content_length or len(body)).encode()))
    reads, sent = 0, []
    async def receive():
        nonlocal reads
        reads += 1
        return {'type': 'http.request', 'body': body if reads == 1 else b'', 'more_body': False}
    async def send(message):
        sent.append(message)
    await app({'type': 'http', 'asgi': {'version': '3.0'}, 'http_version': '1.1', 'method': 'POST',
               'scheme': 'http', 'path': '/api/v1/analyze', 'root_path': '', 'query_string': b'',
               'headers': headers, 'server': ('test', 80), 'client': ('127.0.0.1', 1234)}, receive, send)
    status = next(m['status'] for m in sent if m['type'] == 'http.response.start')
    result = json.loads(b''.join(m.get('body', b'') for m in sent if m['type'] == 'http.response.body'))
    return status, result, reads


class ApiTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.environment = patch.dict(os.environ, {'AI_SERVICE_API_KEY': KEY, 'GEMINI_API_KEY': 'fake-only', 'DAMAGE_ANALYSIS_ENABLED': 'true'})
        self.environment.start(); self.addCleanup(self.environment.stop)
        self.provider_patch = patch('app.damage_analysis.service.GeminiVisionProvider')
        self.provider = self.provider_patch.start().return_value
        self.addCleanup(self.provider_patch.stop)
        self.provider.analyze.return_value = GeminiAnalysis.model_validate(success())
        app = FastAPI(); app.include_router(api.router)
        self.app = ServiceSecurityMiddleware(app)
        self.images = [('image', photo(), 'image/png'), ('context_image', photo(11), 'image/png')]

    async def test_success_has_both_images_no_fabricated_confidence_or_boxes(self):
        status, result, _ = await call(self.app, self.images)
        self.assertEqual(200, status, result)
        self.assertEqual('gemini-vision-v1', result['schemaVersion'])
        self.assertIsNone(result['confidenceScore'])
        self.assertEqual([], result['detections'])
        self.assertIsNone(result['repairRecommendations'][0]['partReplacementRequired'])
        self.provider.analyze.assert_called_once()

    async def test_missing_duplicate_and_false_mime_photos_fail_before_paid_work(self):
        for images, expected in [(self.images[:1], 422),
                ([self.images[0], ('context_image', photo(), 'image/png')], 400),
                ([('image', photo(), 'image/jpeg'), self.images[1]], 400),
                ([('image', b'not a photo', 'image/png'), self.images[1]], 400)]:
            status, result, _ = await call(self.app, images)
            self.assertEqual(expected, status, result)
        self.provider.analyze.assert_not_called()

    async def test_authentication_and_body_limits_precede_multipart_or_provider(self):
        self.assertEqual((401, 0), (lambda x: (x[0], x[2]))(await call(self.app, self.images, authenticated=False)))
        self.assertEqual((413, 0), (lambda x: (x[0], x[2]))(await call(self.app, [], content_length=23*1024*1024)))
        self.provider.analyze.assert_not_called()

    async def test_uncertain_damage_requests_photos_and_never_becomes_minor(self):
        value = success()
        value.update(analysisOutcome='NEEDS_MORE_PHOTOS', damageSeverity='UNKNOWN', visualFindings=[], additionalPhotoGuidance='Aynı bölgeyi net ışıkta iki ayrı fotoğrafla gösterin.')
        self.provider.analyze.return_value = GeminiAnalysis.model_validate(value)
        status, result, _ = await call(self.app, self.images)
        self.assertEqual(200, status)
        self.assertEqual('UNKNOWN', result['damageSeverity'])
        self.assertEqual([], result['damageTypes'])
        self.assertEqual([], result['repairRecommendations'])

    async def test_provider_failure_is_not_a_successful_empty_analysis(self):
        self.provider.analyze.side_effect = ProviderError('Servis geçici olarak kullanılamıyor.')
        status, _, _ = await call(self.app, self.images)
        self.assertEqual(502, status)

    async def test_disabled_or_unconfigured_provider_rejects_before_body_read(self):
        for config in ({'DAMAGE_ANALYSIS_ENABLED': 'false'}, {'GEMINI_API_KEY': ''}):
            with patch.dict(os.environ, config):
                status, _, reads = await call(self.app, self.images)
                self.assertEqual((503, 0), (status, reads))
        self.provider.analyze.assert_not_called()


class ImageTests(unittest.TestCase):
    def test_shared_contract_example_passes_python_schema(self):
        from pathlib import Path
        from app.damage_analysis.schemas import AnalysisResponse
        path = Path(__file__).resolve().parents[2]/'contracts/gemini-vision-v1.example.json'
        response = AnalysisResponse.model_validate_json(path.read_text(encoding='utf-8'))
        self.assertEqual('DAMAGE_DETECTED', response.analysisOutcome)

    def test_decoding_strips_metadata_and_bounds_provider_resolution(self):
        with Image.open(io.BytesIO(photo())) as source:
            metadata = Image.Exif()
            metadata[270] = 'PRIVATE_METADATA_MUST_NOT_BE_FORWARDED'
            metadata[274] = 6
            raw = io.BytesIO()
            source.save(raw, format='JPEG', exif=metadata)
        encoded = prepare(raw.getvalue())
        with Image.open(io.BytesIO(encoded.jpeg)) as result:
            self.assertEqual('JPEG', result.format)
            self.assertFalse(result.getexif())
            self.assertLessEqual(max(result.size), 2048)

    def test_pixel_limit_is_checked_from_header_before_large_decode(self):
        import struct
        import zlib
        raw = photo()
        header = struct.pack('>II', 6000, 5000) + raw[24:29]
        oversized = raw[:16] + header + struct.pack('>I', zlib.crc32(b'IHDR'+header) & 0xffffffff) + raw[33:]
        with self.assertRaisesRegex(ValueError, '24 MP'):
            prepare(oversized)

    def test_blank_and_undersized_images_are_rejected(self):
        for size in [(320, 320), (32, 32)]:
            data = io.BytesIO(); Image.new('RGB', size).save(data, format='PNG')
            with self.assertRaises(ValueError):
                prepare(data.getvalue())


if __name__ == '__main__':
    unittest.main()
