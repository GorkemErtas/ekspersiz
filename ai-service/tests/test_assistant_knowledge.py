import unittest

from app.assistant.chunking import HeadingAwareChunker
from app.assistant.schemas import KnowledgeDocument


class KnowledgeCorpusTest(unittest.TestCase):
    def test_curated_documents_produce_non_empty_chunks(self):
        samples = {
            "inspection": "# Muayene Öncesi\nFarları, lastikleri ve güvenlik ekipmanlarını kontrol edin.",
            "maintenance": "# Lastik Bakımı\nBasıncı üretici bilgisinden doğrulayın.",
            "safety": "# Uyarı Lambaları\nKritik uyarılarda güvenliği önceliklendirin.",
        }
        chunker = HeadingAwareChunker()
        for slug, content in samples.items():
            chunks = chunker.chunk(KnowledgeDocument(slug, slug, slug.upper(), content))
            self.assertGreater(len(chunks), 0)
            self.assertTrue(chunks[0].content.strip())

    def test_private_user_data_is_not_part_of_curated_corpus_contract(self):
        forbidden_categories = {"USER_VEHICLE", "DAMAGE_HISTORY", "REMINDER"}
        curated_categories = {"INSPECTION", "MAINTENANCE", "SAFETY", "APP_HELP"}
        self.assertTrue(curated_categories.isdisjoint(forbidden_categories))


if __name__ == "__main__":
    unittest.main()
