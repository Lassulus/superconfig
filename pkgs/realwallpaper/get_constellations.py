from astropy.coordinates import SkyCoord, ITRS, representation
from astropy.time import Time
import json
import sys


def convert_to_itrs(coord):
    c = SkyCoord(coord[0], coord[1], unit='degree', frame='icrs')
    c_itrs = c.transform_to(ITRS(obstime=Time.now()))
    rep = c_itrs.represent_as(representation.UnitSphericalRepresentation)
    return [rep.lat.deg, rep.lon.deg]


def points_to_lines(points):
    lines = []
    for x in range(len(points) - 1):
        lines.append([points[x], points[x+1]])
    return lines


def main():
    with open(sys.argv[1]) as f:
        constellations = json.load(f)['features']

    output = []

    for const in constellations:
        for line in const['geometry']['coordinates']:
            transformed_line = []
            for point in line:
                transformed_line.append(convert_to_itrs(point))

            line_combined = points_to_lines(transformed_line)
            for l in line_combined:  # noqa
                output.append(f'{l[0][0]} {l[0][1]} {l[1][0]} {l[1][1]} # {const["id"]}')  # noqa

    print('\n'.join(output))


if __name__ == "__main__":
    main()
