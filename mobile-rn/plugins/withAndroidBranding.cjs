const { withFinalizedMod } = require('expo/config-plugins');
const { readdir, readFile, writeFile } = require('node:fs/promises');
const { join } = require('node:path');

function insetForeground(xml) {
  if (xml.includes('android:inset="22%"')) return xml;
  const foreground =
    /<foreground\s+android:drawable="(@(?:mipmap|drawable)\/[a-z0-9_]+)"\s*\/>/;
  if (!foreground.test(xml))
    throw new Error(
      'Unexpected adaptive icon foreground; review branding generation.',
    );
  // 108dp foreground -> 60.48dp artwork. The original bitmap remains intact.
  return xml.replace(
    foreground,
    '<foreground><inset android:inset="22%" android:drawable="$1" /></foreground>',
  );
}

module.exports = (config) =>
  withFinalizedMod(config, [
    'android',
    async (mod) => {
      const resources = join(
        mod.modRequest.platformProjectRoot,
        'app/src/main/res',
      );
      let count = 0;
      for (const directory of await readdir(resources)) {
        if (!directory.startsWith('mipmap-anydpi')) continue;
        for (const name of await readdir(join(resources, directory))) {
          if (!['ic_launcher.xml', 'ic_launcher_round.xml'].includes(name))
            continue;
          const path = join(resources, directory, name);
          await writeFile(path, insetForeground(await readFile(path, 'utf8')));
          count++;
        }
      }
      if (!count)
        throw new Error('Generated Android adaptive icons are missing.');
      return mod;
    },
  ]);
module.exports.insetForeground = insetForeground;
