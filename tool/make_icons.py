"""Builds every app icon the stores ask for from one piece of artwork.

    python tool/make_icons.py path/to/app_logo.png

The source arrives as a finished icon: the mascot, a brain holding a ticked-off
calendar, on a rounded black tile. Neither store wants that. Apple and Google
each cut their own shape out of a plain square, so a tile with its corners
already rounded comes out as a rounded tile inside a rounded tile; and
Android's adaptive icon wants the artwork and the background as two separate
layers so the launcher can mask and move them independently.

So the mascot is lifted off its tile and set on a clean black square, and
everything is cut from that:

  store/app_store_icon_1024.png     App Store listing and Xcode, 1024, no alpha
  store/play_store_icon_512.png     Play Console listing, 512
  ios/.../AppIcon.appiconset/*      every size in Contents.json, no alpha
  android mipmaps                   legacy square and round launcher icons,
                                    plus the adaptive foreground, background
                                    and monochrome layers at every density
  assets/brand/icon.png             the copy the app shows on its own screens

The source is about 450 pixels square and the largest output is 1024, so the
artwork is enlarged a little over twice. It is resampled carefully and
sharpened a touch, but a larger original will always look crisper — rerun this
with one if it turns up.

Needs Pillow, numpy and scipy.
"""

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
IOS = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
STORE = os.path.join(ROOT, 'store')

# Black, which is what the mascot was drawn on. It was briefly the navy of the
# app's night sky — a tie to the theme — but the pink of the brain and the red
# of the calendar are warm colours, and they carry further off black than off
# anything else. Flat rather than a gradient: at 48 pixels a gradient is a
# smudge, and an icon is 48 pixels more often than it is 1024.
TOP = (0, 0, 0)
BOTTOM = (0, 0, 0)

# How much of the square the artwork fills. The stores' own masks only take
# the corners, so the icon can run close to the edge.
ICON_FILL = 0.80

# The adaptive foreground is 108dp, of which a launcher shows at most the
# middle 72dp, and a round launcher only a circle of it. The mascot is sized
# so its farthest point (the tip of a sparkle) stays inside that circle.
ADAPTIVE_RADIUS = 35.5 / 108


def gradient(size):
    """The background: TOP to BOTTOM, top to bottom. Both black at the moment,
    which makes it a flat fill — the ramp stays for the day somebody wants a
    coloured one back."""
    img = Image.new('RGB', (1, size))
    for y in range(size):
        t = y / max(1, size - 1)
        img.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return img.resize((size, size))


def lift_artwork(src):
    """The mascot on its own, with a soft edge, as RGBA, cropped square.

    The tile is found by flooding in from the border over anything dark and
    colourless. Its legs and hand are nearly as dark, but brown, so they stop
    the flood; what the flood reaches is tile, and everything else is mascot,
    including the tile-dark gaps inside it that the flood cannot get to.
    """
    im = np.array(src.convert('RGB')).astype(np.int32)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    brightest = im.max(2)

    tileish = (brightest <= 24) & ((r - np.minimum(g, b)) <= 7)
    lab, _ = ndimage.label(tileish)
    edges = np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])
    drawing = ~np.isin(lab, [v for v in np.unique(edges) if v])
    drawing = ndimage.binary_opening(drawing)

    # What is left of the tile's own lit rim is a thin dim arc in a corner;
    # the sparkles are as small, but bright.
    lab, count = ndimage.label(drawing)
    keep = [
        i for i in range(1, count + 1)
        if (lab == i).sum() >= 150 and brightest[lab == i].mean() >= 90
    ]
    drawing = np.isin(lab, keep)

    # A pixel of feather, and the edge un-mixed from the black it was drawn
    # over, so no dark fringe comes along onto the background.
    alpha = ndimage.gaussian_filter(drawing.astype(float), 0.7)
    alpha = np.clip((alpha - 0.05) / 0.9, 0, 1)
    rgb = im.astype(float)
    unmixed = np.clip(rgb / np.maximum(alpha, 0.35)[..., None], 0, 255)
    rgb = np.where((alpha < 0.999)[..., None], unmixed, rgb)
    art = Image.fromarray(
        np.dstack([rgb, alpha * 255]).round().astype(np.uint8), 'RGBA')

    # Square, centred on the drawing, with a little room round it.
    ys, xs = np.nonzero(drawing)
    left, right, top, bottom = xs.min(), xs.max(), ys.min(), ys.max()
    cx, cy = (left + right) / 2, (top + bottom) / 2
    half = max(right - left, bottom - top) / 2 * 1.04
    return art.crop(tuple(round(v) for v in (cx - half, cy - half, cx + half, cy + half)))


def reach(art):
    """How far the drawing reaches from the centre of its square, as a share
    of half the square: over 1 means it runs into the corners."""
    size = art.size[0]
    ys, xs = np.nonzero(np.array(art.getchannel('A')) > 128)
    return np.hypot(xs - size / 2, ys - size / 2).max() / (size / 2)


def enlarge(art, size):
    big = art.resize((size, size), Image.LANCZOS)
    rgb = big.convert('RGB').filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    rgb.putalpha(big.getchannel('A'))
    return rgb


def compose(art, size, fill):
    """The artwork centred on the square, filling [fill] of it."""
    canvas = gradient(size).convert('RGBA')
    inner = round(size * fill)
    piece = enlarge(art, inner)
    off = (size - inner) // 2
    canvas.alpha_composite(piece, (off, off))
    return canvas


def rounded(img, radius_frac=0.225):
    """The same square with transparent rounded corners, for places that show
    the icon as a picture rather than letting a system mask it."""
    size = img.size[0]
    mask = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 4 - 1, size * 4 - 1), radius=int(size * 4 * radius_frac), fill=255
    )
    out = img.convert('RGBA')
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def circle(img):
    size = img.size[0]
    mask = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    out = img.convert('RGBA')
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def monochrome(piece):
    """One colour for themed icons (Android 13+), shaped by the mascot's
    outline and shaded by how light each part is: the brain and the calendar
    solid, the legs, eyes and smile a lighter wash of the tint, so the face
    and the figure both survive it."""
    lum = np.array(piece.convert('L')).astype(float)
    shade = 0.42 + 0.58 * np.clip((lum - 45) / 90, 0, 1)
    alpha = np.array(piece.getchannel('A')).astype(float) * shade
    white = Image.new('RGBA', piece.size, (255, 255, 255, 255))
    white.putalpha(Image.fromarray(alpha.round().astype(np.uint8)))
    return white


def main(path):
    src = Image.open(path)
    art = lift_artwork(src)

    master = compose(art, 1024, ICON_FILL)
    master_rgb = master.convert('RGB')

    os.makedirs(STORE, exist_ok=True)
    # Apple rejects an App Store icon with an alpha channel.
    master_rgb.save(os.path.join(STORE, 'app_store_icon_1024.png'))
    master_rgb.resize((512, 512), Image.LANCZOS).save(
        os.path.join(STORE, 'play_store_icon_512.png'))

    # iOS: every slot Contents.json lists, opaque.
    contents = json.load(open(os.path.join(IOS, 'Contents.json')))
    for image in contents['images']:
        points = float(image['size'].split('x')[0])
        scale = int(image['scale'].rstrip('x'))
        px = round(points * scale)
        name = image.get('filename') or 'Icon-App-%sx%s@%sx.png' % (
            image['size'].split('x')[0], image['size'].split('x')[0], scale)
        image['filename'] = name
        master_rgb.resize((px, px), Image.LANCZOS).save(os.path.join(IOS, name))
    json.dump(contents, open(os.path.join(IOS, 'Contents.json'), 'w'), indent=2)

    # Android.
    adaptive_fill = 2 * ADAPTIVE_RADIUS / reach(art)
    densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    for name, factor in densities.items():
        folder = os.path.join(RES, 'mipmap-' + name)
        legacy = round(48 * factor)
        layer = round(108 * factor)

        # Pre-Android-8 launchers: a finished icon, square and round.
        rounded(master.resize((legacy, legacy), Image.LANCZOS), 0.18).save(
            os.path.join(folder, 'ic_launcher.png'))
        circle(master.resize((legacy, legacy), Image.LANCZOS)).save(
            os.path.join(folder, 'ic_launcher_round.png'))

        # Adaptive: the launcher masks these to its own shape and moves the
        # foreground against the background, so they are separate layers.
        gradient(layer).save(os.path.join(folder, 'ic_launcher_background.png'))
        inner = round(layer * adaptive_fill)
        at = ((layer - inner) // 2, (layer - inner) // 2)
        piece = enlarge(art, inner)
        fg = Image.new('RGBA', (layer, layer), (0, 0, 0, 0))
        fg.alpha_composite(piece, at)
        fg.save(os.path.join(folder, 'ic_launcher_foreground.png'))

        mono = Image.new('RGBA', (layer, layer), (0, 0, 0, 0))
        mono.alpha_composite(monochrome(piece), at)
        mono.save(os.path.join(folder, 'ic_launcher_monochrome.png'))

    # The app's own copy, for the About screen.
    rounded(master.resize((384, 384), Image.LANCZOS)).save(
        os.path.join(ROOT, 'assets', 'brand', 'icon.png'))

    print('built from %s (%dx%d); adaptive fill %.2f' % (
        os.path.basename(path), *src.size, adaptive_fill))


if __name__ == '__main__':
    main(sys.argv[1])
