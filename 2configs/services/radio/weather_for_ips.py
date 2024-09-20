import geoip2.database
import fileinput
import json
import requests
import os
import random
import sys


# https://open-meteo.com/en/docs
def weather_code_representation(code: int) -> str:
    if code == 0:
        return 'clear sky'
    if code == 1:
        return 'mainly clear'
    if code == 2:
        return 'partly cloudy'
    if code == 3:
        return 'overcast'
    if code == 45:
        return 'fog'
    if code == 48:
        return 'depositing rime fog'
    if code == 51:
        return 'light drizzle'
    if code == 53:
        return 'moderate drizzle'
    if code == 55:
        return 'heavy drizzle'
    if code == 56:
        return 'light freezing drizzle'
    if code == 57:
        return 'heavy freezing drizzle'
    if code == 61:
        return 'light rain'
    if code == 63:
        return 'moderate rain'
    if code == 65:
        return 'heavy rain'
    if code == 66:
        return 'light freezing rain'
    if code == 67:
        return 'heavy freezing rain'
    if code == 71:
        return 'light snow'
    if code == 73:
        return 'moderate snow'
    if code == 75:
        return 'heavy snow'
    if code == 77:
        return 'light snow grains'
    if code == 80:
        return 'light rain showers'
    if code == 81:
        return 'moderate rain showers'
    if code == 82:
        return 'heavy rain showers'
    if code == 85:
        return 'light snow showers'
    if code == 86:
        return 'heavy snow showers'
    if code == 95:
        return 'thunderstorm'
    if code == 96:
        return 'thunderstorm with light hail'
    if code == 99:
        return 'thunderstorm with heavy hail'
    return f'unknown weather code {code}'


def downfall_representation(precipitation: float) -> str:
    if precipitation > 0:
        return f' the precipitation is {precipitation} millimeter'
    else:
        return ''

geoip = geoip2.database.Reader(os.environ['MAXMIND_GEOIP_DB'])
seen = {}
output = []
if len(sys.argv) > 1:
    ips = sys.argv[1:]
else:
    ips = list(fileinput.input())
if len(ips) > 5:
    output.append('weather report.')
    for ip in fileinput.input():
        if "80.147.140.51" in ip:
            output.append(
                'Weather report for c-base.'
                'temperature of -270 degrees, '
            )
        else:
            try:
                location = geoip.city(ip.strip())
                if location.city.geoname_id not in seen:
                    seen[location.city.geoname_id] = True
                    url = (
                        f'https://api.open-meteo.com/v1/forecast'
                        f'?latitude={location.location.latitude}'
                        f'&longitude={location.location.longitude}'
                        f'&current=temperature_2m,weather_code'
                    )
                    resp = requests.get(url)
                    weather = json.loads(resp.text)
                    output.append(
                        f'{location.city.name}, {location.country.name}. '
                        f'{weather_code_representation(weather["current"]["weather_code"])}. '
                        f'{weather["current"]["temperature_2m"]} degrees.'
                    )
            except:  # noqa E722
                pass

else:
    for ip in ips:
        if "80.147.140.51" in ip:
            output.append(
                'Weather report for c-base, space. '
                'It is empty space outside '
                'with a temperature of -270 degrees, '
                'a lightspeed of 299792 kilometers per second '
                'and a humidity of Not a Number percent. '
                f'The probability of reincarnation is {random.randrange(0, 100)} percent. '
            )
        else:
            try:
                location = geoip.city(ip.strip())
                if location.city.geoname_id not in seen:
                    seen[location.city.geoname_id] = True
                    url = (
                        f'https://api.open-meteo.com/v1/forecast'
                        f'?latitude={location.location.latitude}'
                        f'&longitude={location.location.longitude}'
                        '&current=temperature_2m,precipitation,weather_code,relative_humidity_2m,wind_speed_10m'
                        '&wind_speed_unit=ms'
                    )
                    resp = requests.get(url)
                    weather = json.loads(resp.text)
                    output.append(
                        f'Weather report for {location.city.name}, {location.country.name}. '
                        f'It is {weather_code_representation(weather["current"]["weather_code"])} outside'
                        f'{downfall_representation(weather["current"]["precipitation"])}, '
                        f'with a temperature of {weather["current"]["temperature_2m"]} degrees, '
                        f'a wind speed of {weather["current"]["wind_speed_10m"]} meters per second '
                        f'and a humidity of {weather["current"]["relative_humidity_2m"]} percent. '
                    )
            except:  # noqa E722
                pass

print('\n'.join(output))
