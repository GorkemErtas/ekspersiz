"""Read-only verification that training/evaluation never changed either source corpus."""
import argparse
import hashlib
import json
from pathlib import Path

from .fetch_syndcar import file_hash


def verify(output):
    app = Path(__file__).resolve().parents[1]
    historical = json.loads((app.parent/'docs/ml/HITL_DATASET_AUDIT.json').read_text(encoding='utf-8'))
    raw = app/'datasets/raw'
    fingerprint = hashlib.sha256()
    for source in sorted(raw.iterdir()):
        for pattern in ('**/ann/*.json', '**/img/*'):
            for path in sorted(source.glob(pattern)):
                fingerprint.update(str(path.relative_to(raw)).encode()+bytes.fromhex(file_hash(path)))
    if fingerprint.hexdigest() != historical['raw_image_annotation_fingerprint']:
        raise ValueError('HITL source images/annotations changed')
    for source in historical['sources']:
        if file_hash(raw/source['directory']/'meta.json') != source['meta_sha256']:
            raise ValueError('HITL source catalog changed')
    external = app/'datasets/external/syndcar-v1'
    audit = json.loads((external/'audit.json').read_text(encoding='utf-8'))
    if file_hash(external/'SYNDCAR.zip') != audit['archive_sha256']:
        raise ValueError('SYNDCAR source archive changed')
    for entry in audit['files']:
        path = (external/entry['path']).resolve()
        if not path.is_relative_to(external.resolve()) or file_hash(path) != entry['sha256']:
            raise ValueError('SYNDCAR extracted source file changed')
    report = {'hitl_images_annotations_unchanged':True, 'hitl_source_catalogs_unchanged':True,
              'hitl_fingerprint':fingerprint.hexdigest(), 'syndcar_archive_unchanged':True,
              'syndcar_archive_sha256':audit['archive_sha256'], 'syndcar_extracted_files_verified':len(audit['files'])}
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report),flush=True)
    return report


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True,type=Path)
    verify(parser.parse_args().output)
