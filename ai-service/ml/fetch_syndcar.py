"""Fetch the publisher's CC BY 4.0 SYNDCAR v1; verify archive, never execute bundled code."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import time
import zipfile

import requests

EXPECTED_SHA256 = '04bc00e42bc0ce6cfa551524f530e0c57d9990e9c1c787557d653bb526d76f8c'
PUBLISHER = 'https://data.mendeley.com/public-api/datasets/hzpj48krdt'


def file_hash(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(8*1024**2), b''):
            digest.update(chunk)
    return digest.hexdigest()


def fetch(output):
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    response = requests.get(PUBLISHER, timeout=60)
    response.raise_for_status()
    metadata = response.json()
    license_info = metadata['data_licence']
    if metadata['version'] != 1 or license_info['short_name'] != 'CC BY 4.0':
        raise ValueError('Publisher version/license differs from the reviewed source')
    source = next(f for f in metadata['files'] if f['filename'] == 'SYNDCAR.zip')['content_details']
    if source['sha256_hash'] != EXPECTED_SHA256:
        raise ValueError('Publisher archive identity changed')
    (output/'publisher.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    archive = output/'SYNDCAR.zip'
    if not archive.exists():
        partial = archive.with_suffix('.zip.partial')
        start = time.perf_counter()
        with requests.get(source['download_url'], stream=True, timeout=(30, 120)) as download:
            download.raise_for_status()
            with partial.open('wb') as stream:
                total = 0
                for chunk in download.iter_content(8*1024**2):
                    stream.write(chunk)
                    total += len(chunk)
                    if total//(128*1024**2) != (total-len(chunk))//(128*1024**2):
                        print(json.dumps({'downloaded_mib': total/1024**2, 'seconds': time.perf_counter()-start}), flush=True)
        if partial.stat().st_size != source['size'] or file_hash(partial) != EXPECTED_SHA256:
            raise ValueError('Downloaded archive checksum/size mismatch')
        partial.rename(archive)
    if file_hash(archive) != EXPECTED_SHA256:
        raise ValueError('Local archive checksum mismatch')
    extracted = output/'content'
    files = []
    with zipfile.ZipFile(archive) as dataset:
        if sum(f.file_size for f in dataset.infolist()) > 10*1024**3:
            raise ValueError('Unexpected archive uncompressed size')
        for entry in dataset.infolist():
            name = PurePosixPath(entry.filename.replace('\\', '/'))
            if entry.is_dir():
                continue
            if name.is_absolute() or '..' in name.parts or any(':' in p for p in name.parts):
                raise ValueError('Unsafe archive member')
            allowed = name.suffix.lower() in ('.jpg', '.jpeg', '.png', '.yaml', '.yml', '.md') or (
                name.suffix.lower() == '.txt' and any('labels_damage' in p for p in name.parts))
            if not allowed:
                continue
            destination = (extracted/Path(*name.parts)).resolve()
            if not destination.is_relative_to(extracted.resolve()):
                raise ValueError('Extraction escaped dataset directory')
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not destination.exists():
                with dataset.open(entry) as source_stream, destination.open('wb') as target:
                    for chunk in iter(lambda: source_stream.read(4*1024**2), b''):
                        target.write(chunk)
            files.append({'path': destination.relative_to(output).as_posix(), 'bytes': destination.stat().st_size, 'sha256': file_hash(destination)})
    attribution = ('SYNDCAR v1, Loureiro et al., DTx CoLAB / Universidade do Minho, '
                   'https://doi.org/10.17632/hzpj48krdt.1, CC BY 4.0 '
                   '(https://creativecommons.org/licenses/by/4.0/). '
                   'Changes: selective extraction and audit only; not used to train the HITL comparison candidates.\n')
    (output/'ATTRIBUTION.txt').write_text(attribution, encoding='utf-8')
    report = {'source': 'https://data.mendeley.com/datasets/hzpj48krdt/1', 'doi': '10.17632/hzpj48krdt.1',
              'license': license_info, 'archive_sha256': EXPECTED_SHA256, 'files': files,
              'training_use': False, 'bundled_code_executed': False, 'attribution': attribution.strip()}
    (output/'audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'verified_archive': EXPECTED_SHA256, 'extracted_files': len(files)}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('datasets/external/syndcar-v1'))
    fetch(parser.parse_args().output)
