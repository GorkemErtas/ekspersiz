# Image validation fixture

`48mp.jpg` is the existing synthetic 8000 × 6000 JPEG copied byte for byte from
`mobile/test/fixtures/inspection/48mp.jpg` during the React Native cleanup.
The API test checks its 48 MP dimensions and rejects it before calling Gemini.
The AI test suite now owns this fixture and does not require the Flutter tree.

The optional native image contract test accepts `MOBILE_IMAGE_CONTRACT_DIR` with
`detail.jpg` and `overview.jpg` produced by the React Native native image preparer.
It mocks Gemini and verifies that both optimized images pass server validation.
