"""Portable split identity: ignore only the machine-local source root, never labels or image hashes."""
import hashlib
import json


def split_signature(document):
    portable = dict(document)
    portable['info'] = {k:v for k,v in document.get('info', {}).items() if k != 'source_root'}
    payload = json.dumps(portable, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)
    return hashlib.sha256(payload.encode('utf-8')).hexdigest()
