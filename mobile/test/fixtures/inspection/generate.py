"""Regenerate synthetic fixtures using the AI service's Pillow environment."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent
large = Image.new('RGB', (8000, 6000), 'gray')
ImageDraw.Draw(large).rectangle((0, 0, 4000, 3000), fill='red')
large.save(root / '48mp.jpg', quality=90)
small = Image.new('RGB', (640, 320), 'blue')
ImageDraw.Draw(small).rectangle((0, 0, 319, 319), fill='red')
for orientation in range(1, 9):
    exif = Image.Exif()
    exif[274] = orientation
    exif[270] = 'PRIVATE_METADATA'
    small.save(root / f'orientation-{orientation}.jpg', quality=95, exif=exif)
small.save(root / 'still.webp')
small.save(root / 'animated.webp', save_all=True,
           append_images=[Image.new('RGB', small.size, 'green')], duration=100, loop=0)
small.save(root / 'animated.png', save_all=True,
           append_images=[Image.new('RGB', small.size, 'green')], duration=100, loop=0)
