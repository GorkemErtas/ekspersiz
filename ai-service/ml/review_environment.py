"""Record actual installed framework/dependency licenses and their license-file hashes."""
import argparse
import hashlib
from importlib import metadata
import json
from pathlib import Path
import sys


def review(output):
    packages = []
    for dist in sorted(metadata.distributions(), key=lambda d: d.metadata['Name'].lower()):
        name = dist.metadata['Name']
        if name.lower().replace('_', '-') in ('ultralytics', 'yolox', 'rfdetr-plus'):
            raise ValueError(f'Unapproved training package: {name}')
        license_files = []
        for file in dist.files or []:
            path = str(file).lower()
            if ('dist-info/' in path and any(token in path for token in ('license', 'notice', 'copying'))) or (
                len(file.parts) <= 3 and file.name.lower() in ('license', 'license.txt', 'license.md', 'notice')):
                real = Path(dist.locate_file(file))
                if real.is_file():
                    content = real.read_bytes()
                    license_files.append({'path': str(file), 'sha256': hashlib.sha256(content).hexdigest(),
                                          'first_line': next((line.strip() for line in content.decode('utf-8', errors='replace').splitlines() if line.strip()), '')[:180]})
        license_text = dist.metadata.get('License')
        classifiers = [c for c in dist.metadata.get_all('Classifier', []) if c.startswith('License ::')]
        packages.append({'name': name, 'version': dist.version,
                         'license_expression': dist.metadata.get('License-Expression'),
                         'license_metadata': (license_text or '')[:250],
                         'project_urls': dist.metadata.get_all('Project-URL', []),
                         'license_classifiers': classifiers,
                         'license_files': license_files})
    report = {'python': sys.version, 'environment': 'isolated offline training environment; original API environment unchanged',
              'packages': packages, 'prohibited_packages_present': False,
              'note': 'Package license metadata/file identity is recorded separately from pretrained-weight and dataset permissions.'}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'packages': len(packages), 'without_license_metadata_or_files': [p['name'] for p in packages if not (p['license_expression'] or p['license_metadata'] or p['license_classifiers'] or p['license_files'])]}))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    review(parser.parse_args().output)
