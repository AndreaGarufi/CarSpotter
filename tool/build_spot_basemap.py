"""Build the offline map from Natural Earth v5.1.2 and GeoNames IT.zip.

Requires NumPy and Shapely 2.1+. Supply the Natural Earth repository's geojson
directory, or a directory containing the named source files below.
"""

import argparse
from array import array
from collections import defaultdict
from dataclasses import dataclass, field
import gzip
import json
from pathlib import Path
import struct
import sys
import unicodedata
from zipfile import ZipFile

import numpy as np
import shapely
from shapely.geometry import shape


TILE_EXTENT = 65535
MAX_LATITUDE = 85.0511287798


@dataclass
class Tile:
    land: array = field(default_factory=lambda: array('H'))
    lakes: array = field(default_factory=lambda: array('H'))
    borders: array = field(default_factory=lambda: array('H'))
    roads: array = field(default_factory=lambda: array('H'))
    cities: list = field(default_factory=list)
    solid_land: bool = False


@dataclass(frozen=True)
class Place:
    name: str
    longitude: float
    latitude: float
    min_zoom: float
    population: int


def read_features(source, name):
    path = source / f'{name}.geojson'
    return json.loads(path.read_bytes())['features']


def mercator(coordinates):
    longitude, latitude = coordinates.T
    x = (longitude + 180) / 360
    y = (1 - np.arcsinh(np.tan(np.radians(np.clip(latitude, -MAX_LATITUDE, MAX_LATITUDE)))) / np.pi) / 2
    return np.column_stack((x, y))


def tile_coordinates(coordinates, column, row, dimension):
    local = (np.asarray(coordinates) * dimension - (column, row)) * TILE_EXTENT
    return np.clip(np.rint(local), 0, TILE_EXTENT).astype('<u2')


def parts(geometry, kind):
    if geometry.geom_type == kind:
        yield geometry
    elif hasattr(geometry, 'geoms'):
        for part in geometry.geoms:
            yield from parts(part, kind)


def clipped_tiles(geometry, target_depth, depth=0, column=0, row=0):
    if geometry.is_empty:
        return
    if depth == target_depth:
        yield column, row, geometry
        return

    dimension = 1 << (depth + 1)
    west, north, east, south = geometry.bounds
    for x in (2 * column, 2 * column + 1):
        for y in (2 * row, 2 * row + 1):
            left, right = x / dimension, (x + 1) / dimension
            top, bottom = y / dimension, (y + 1) / dimension
            if east < left or west > right or south < top or north > bottom:
                continue
            clipped = shapely.clip_by_rect(geometry, left, top, right, bottom)
            yield from clipped_tiles(clipped, target_depth, depth + 1, x, y)


def coordinates_for_triangles(geometry):
    if not geometry.is_valid:
        geometry = shapely.make_valid(geometry)
    for polygon in parts(geometry, 'Polygon'):
        for triangle in shapely.constrained_delaunay_triangles(polygon).geoms:
            yield from list(triangle.exterior.coords)[:3]


def coordinates_for_segments(geometry):
    for line in parts(geometry, 'LineString'):
        points = list(line.coords)
        for start, end in zip(points, points[1:]):
            yield start
            yield end


def add_geometry(tiles, zoom, features, layer, tolerance):
    dimension = 1 << zoom
    is_fill = layer in ('land', 'lakes')
    tile_area = 1 / dimension**2
    coordinates_for_geometry = (
        coordinates_for_triangles if is_fill else coordinates_for_segments
    )

    for feature in features:
        geometry = shapely.transform(shape(feature['geometry']), mercator)
        geometry = geometry.simplify(tolerance, preserve_topology=is_fill)
        for column, row, clipped in clipped_tiles(geometry, zoom):
            index = row * dimension + column
            if layer == 'land' and clipped.area >= tile_area * (1 - 1e-12):
                tiles[index].solid_land = True
                tiles[index].land = array('H')
                continue
            coordinates = list(coordinates_for_geometry(clipped))
            if not coordinates:
                continue
            packed = tile_coordinates(coordinates, column, row, dimension)
            getattr(tiles[index], layer).frombytes(packed.tobytes())


def main_road(feature):
    properties = feature['properties']
    return properties['type'] in {'Major Highway', 'Secondary Highway', 'Beltway', 'Bypass'} or (
        properties['type'] == 'Road' and properties['scalerank'] <= 7
    )


def world_cities(source):
    for feature in read_features(source, 'ne_10m_populated_places'):
        properties = feature['properties']
        longitude, latitude = feature['geometry']['coordinates']
        name = properties.get('NAME_IT')
        if not name or name == '-99':
            name = properties['NAME']
        yield Place(name, longitude, latitude, properties['MIN_ZOOM'], properties['POP_MAX'])


def geonames_places(archive):
    inhabited = {'PPLC', 'PPLA', 'PPLA2', 'PPLA3', 'PPLA4', 'PPL', 'PPLX', 'PPLL'}
    with ZipFile(archive) as countries, countries.open('IT.txt') as entries:
        for entry in entries:
            fields = entry.decode('utf-8').split('\t')
            code = fields[7]
            if fields[6] != 'P' or code not in inhabited:
                continue
            population = int(fields[14] or '0')
            min_zoom = 13.5
            if population >= 20000:
                min_zoom = 10
            elif population >= 5000 or code.startswith('PPLA'):
                min_zoom = 11
            elif population >= 1000:
                min_zoom = 12
            yield Place(fields[1], float(fields[5]), float(fields[4]), min_zoom, population)


def additional_places(archive, cities):
    names = defaultdict(list)

    def name_key(name):
        normalized = unicodedata.normalize('NFKD', name.casefold())
        return ''.join(char for char in normalized if not unicodedata.combining(char))

    for city in cities:
        names[name_key(city.name)].append(city)

    for place in sorted(geonames_places(archive), key=lambda place: -place.population):
        matches = names[name_key(place.name)]
        if any(abs(place.latitude - other.latitude) < 0.015 and
               abs(place.longitude - other.longitude) < 0.02 for other in matches):
            continue
        matches.append(place)
        yield place


def label_tiles(zoom, cities):
    dimension = 1 << zoom
    tiles = defaultdict(list)
    for priority, city in enumerate(cities):
        x, y = mercator(np.asarray([(city.longitude, city.latitude)]))[0]
        column = min(int(x * dimension), dimension - 1)
        row = min(int(y * dimension), dimension - 1)
        a, b = tile_coordinates([(x, y)], column, row, dimension)[0]
        tiles[row * dimension + column].append(
            (a, b, priority, round(city.min_zoom * 10), city.name.encode('utf-8'))
        )
    return tiles


def write_labels(stream, labels):
    stream.write(struct.pack('<H', len(labels)))
    for x, y, priority, min_zoom, name in labels:
        stream.write(struct.pack('<HHHHH', x, y, priority, min_zoom, len(name)))
        stream.write(name)
        if len(name) % 2:
            stream.write(b'\0')


def write_grid(stream, zoom, tiles):
    stream.write(struct.pack('<HH', zoom, len(tiles)))
    for index, tile in sorted(tiles.items()):
        stream.write(struct.pack('<HH', index, tile.solid_land))
        for coordinates in (tile.land, tile.lakes, tile.borders, tile.roads):
            stream.write(struct.pack('<I', len(coordinates)))
            stream.write(coordinates.tobytes())
        write_labels(stream, tile.cities)


def main(source, destination, geonames):
    if sys.byteorder != 'little':
        raise RuntimeError('The map asset requires little-endian coordinate arrays')

    borders = read_features(source, 'ne_50m_admin_0_boundary_lines_land')
    cities = sorted(world_cities(source), key=lambda city: -city.population)
    overview_zoom, detail_zoom, local_zoom = 3, 7, 11
    overview = defaultdict(Tile)
    add_geometry(overview, overview_zoom, read_features(source, 'ne_50m_land'), 'land', 0.00008)
    add_geometry(overview, overview_zoom, borders, 'borders', 0.00004)
    for index, labels in label_tiles(overview_zoom, (city for city in cities if city.min_zoom < 6)).items():
        overview[index].cities = labels

    details = defaultdict(Tile)
    add_geometry(details, detail_zoom, read_features(source, 'ne_10m_land'), 'land', 0.000007)
    add_geometry(details, detail_zoom, read_features(source, 'ne_10m_lakes'), 'lakes', 0.000007)
    add_geometry(details, detail_zoom, borders, 'borders', 0.00004)
    roads = filter(main_road, read_features(source, 'ne_10m_roads'))
    add_geometry(details, detail_zoom, roads, 'roads', 0.000005)
    for index, labels in label_tiles(detail_zoom, cities).items():
        details[index].cities = labels

    local_labels = label_tiles(local_zoom, additional_places(geonames, cities))

    with destination.open('wb') as output:
        with gzip.GzipFile(filename='', fileobj=output, mode='wb', mtime=0) as stream:
            stream.write(b'CSM2')
            write_grid(stream, overview_zoom, overview)
            write_grid(stream, detail_zoom, details)
            stream.write(struct.pack('<HH', local_zoom, len(local_labels)))
            for index, labels in sorted(local_labels.items()):
                stream.write(struct.pack('<I', index))
                write_labels(stream, labels)
    print(f'{len(overview)} overview tiles, {len(details)} detail tiles, {destination.stat().st_size:,} bytes')
    print(f'{sum(map(len, local_labels.values()))} Italian place names from GeoNames (CC BY 4.0)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--geonames', type=Path, required=True, help='GeoNames IT.zip extract')
    arguments = parser.parse_args()
    main(arguments.source, arguments.destination, arguments.geonames)
