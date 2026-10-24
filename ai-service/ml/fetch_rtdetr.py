"""Fetch publisher-designated Apache RT-DETR R18 safetensors at one immutable revision."""
import argparse
import hashlib
import json
from pathlib import Path

import requests


def fetch(output):
    if output.exists():
        raise ValueError('Use a new pretrained asset directory')
    repository = 'PekingU/rtdetr_r18vd'
    response = requests.get(f'https://huggingface.co/api/models/{repository}?blobs=true', timeout=60)
    response.raise_for_status()
    metadata = response.json()
    if metadata['id'] != repository or metadata.get('cardData', {}).get('license') != 'apache-2.0':
        raise ValueError('Publisher weight license/repository differs from the reviewed model card')
    revision = metadata['sha']
    siblings = {row['rfilename']:row for row in metadata['siblings']}
    expected = siblings['model.safetensors']['lfs']['sha256']
    output.mkdir(parents=True)
    files = {}
    for filename in ('config.json','preprocessor_config.json','README.md','model.safetensors'):
        url = f'https://huggingface.co/{repository}/resolve/{revision}/{filename}'
        target = output/filename
        digest = hashlib.sha256()
        with requests.get(url, stream=True, timeout=(30,120)) as download:
            download.raise_for_status()
            with target.open('wb') as stream:
                for chunk in download.iter_content(4*1024**2):
                    stream.write(chunk)
                    digest.update(chunk)
        files[filename] = {'url':url,'sha256':digest.hexdigest(),'bytes':target.stat().st_size}
    if files['model.safetensors']['sha256'] != expected:
        raise ValueError('Publisher safetensors checksum mismatch')
    config = json.loads((output/'config.json').read_text(encoding='utf-8'))
    if config['model_type'] != 'rt_detr' or config['backbone_config']['depths'] != [2,2,2,2]:
        raise ValueError('Publisher architecture differs from the reviewed R18 model')
    record = {'repository':repository,'revision':revision,'license':'Apache-2.0','files':files,
              'model_card':'https://huggingface.co/PekingU/rtdetr_r18vd',
              'framework_license':'Transformers Apache-2.0, recorded separately in environment inventory',
              'remote_code_executed':False,'coco_images_downloaded':False}
    (output/'publisher.json').write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(record), flush=True)
    return record


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('models/pretrained-rtdetr-r18'))
    fetch(parser.parse_args().output)
