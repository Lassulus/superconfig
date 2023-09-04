import geoip2.database
import fileinput
import json
import requests
import os
import random


geoip = geoip2.database.Reader(os.environ['MAXMIND_GEOIP_DB'])
seen = {}
output = []
for ip in fileinput.input():
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
                weather_api_key = os.environ['OPENWEATHER_API_KEY']
                url = (
                    f'https://api.openweathermap.org/data/2.5/onecall'
                    f'?lat={location.location.latitude}'
                    f'&lon={location.location.longitude}'
                    f'&appid={weather_api_key}'
                    f'&units=metric'
                )
                resp = requests.get(url)
                weather = json.loads(resp.text)
                output.append(
                    f'Weather report for {location.city.name}, {location.country.name}. '
                    f'It is {weather["current"]["weather"][0]["description"]} outside '
                    f'with a temperature of {weather["current"]["temp"]:.1f} degrees, '
                    f'a wind speed of {weather["current"]["wind_speed"]:.1f} meters per second '
                    f'and a humidity of {weather["current"]["humidity"]} percent. '
                    f'The probability of precipitation is {weather["hourly"][0]["pop"] * 100:.0f} percent. '
                )
        except:  # noqa E722
            pass

print('\n'.join(output))
