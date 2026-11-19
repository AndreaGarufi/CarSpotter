"""Build the offline globe atlas from Natural Earth's 1:50m country GeoJSON.

Requires NumPy, Pillow and Shapely.
"""

import argparse
import gzip
import json
from pathlib import Path
import struct

import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import shape

from build_spot_basemap import parts


FACE_SIZE = 768
TILE_SIZE = FACE_SIZE + 2
SOURCE_WIDTH, SOURCE_HEIGHT = 4096, 2048


def draw_country_ids(polygons):
    image = Image.new('L', (SOURCE_WIDTH, SOURCE_HEIGHT))
    draw = ImageDraw.Draw(image)

    def pixels(ring):
        return [
            ((x + 180) * SOURCE_WIDTH / 360, (90 - y) * SOURCE_HEIGHT / 180)
            for x, y in ring.coords
        ]

    # Draw larger polygons first so that enclaves fill their host country's holes.
    for country_id, polygon in sorted(polygons, key=lambda entry: -entry[1].area):
        draw.polygon(pixels(polygon.exterior), fill=country_id)
        for ring in polygon.interiors:
            draw.polygon(pixels(ring), fill=0)
    return np.asarray(image)


def cube_atlas(country_ids):
    # Sample two extra pixels per side for the borders. Keep one as a gutter
    # so bilinear filtering works across face seams.
    steps = (np.arange(-2, FACE_SIZE + 2) + 0.5) * 2 / FACE_SIZE - 1
    u, v = np.meshgrid(steps, steps)
    one = np.ones_like(u)
    faces = (
        (one, -v, -u), (-one, -v, u),
        (u, one, v), (u, -one, -v),
        (u, -v, one), (-u, -v, -one),
    )
    ids = np.zeros((2 * TILE_SIZE, 3 * TILE_SIZE), dtype=np.uint8)
    edges = np.zeros_like(ids)
    for face, (x, y, z) in enumerate(faces):
        lon = np.arctan2(x, z)
        lat = np.arcsin(y / np.sqrt(x*x + y*y + z*z))
        col = ((lon / np.pi + 1) * SOURCE_WIDTH / 2).astype(int) % SOURCE_WIDTH
        row = ((0.5 - lat / np.pi) * SOURCE_HEIGHT).astype(int).clip(0, SOURCE_HEIGHT - 1)
        tile = country_ids[row, col]
        center = tile[1:-1, 1:-1]
        border = (center != 0) & (
            (center != tile[:-2, 1:-1]) | (center != tile[2:, 1:-1])
            | (center != tile[1:-1, :-2]) | (center != tile[1:-1, 2:])
        )
        top, left = (face // 3) * TILE_SIZE, (face % 3) * TILE_SIZE
        ids[top:top + TILE_SIZE, left:left + TILE_SIZE] = center
        edges[top:top + TILE_SIZE, left:left + TILE_SIZE] = border
    return ids, edges


def build(source, output):
    features = json.loads(source.read_bytes())['features']
    iso_codes = {feature['properties']['ISO_A2'] for feature in features}
    if len(features) > 255:
        raise ValueError('The atlas stores up to 255 countries')
    countries = []
    polygons = []
    for country_id, feature in enumerate(features, start=1):
        properties = feature['properties']
        code = properties['ISO_A2']
        if code == '-99':
            fallback = properties['ISO_A2_EH']
            code = properties['ADM0_A3'] if fallback in iso_codes else fallback
        name = properties['NAME_IT'] or properties['NAME']
        country_polygons = list(parts(shape(feature['geometry']), 'Polygon'))
        focal_point = max(country_polygons, key=lambda polygon: polygon.area).representative_point()
        countries.append((code, name, focal_point))
        polygons.extend((country_id, polygon) for polygon in country_polygons)

    ids, edges = cube_atlas(draw_country_ids(polygons))
    with output.open('wb') as file:
        with gzip.GzipFile(filename='', mode='wb', fileobj=file, mtime=0) as stream:
            stream.write(b'CSG2')
            stream.write(struct.pack('<HH', len(countries), TILE_SIZE))
            for code, name, focal_point in countries:
                label = name.encode('utf-8')
                stream.write(struct.pack(
                    '<3sxHhh', code.encode('ascii'), len(label),
                    round(focal_point.x * 100), round(focal_point.y * 100),
                ))
                stream.write(label)
            stream.write(ids.tobytes())
            stream.write(edges.tobytes())
    print(f'{len(countries)} countries, {FACE_SIZE} × {FACE_SIZE} pixels per face')
    print(f'{output.stat().st_size:,} compressed bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    build(args.source, args.output)
