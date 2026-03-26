import asyncio
import json
import logging
import os
import re
import sys
from pathlib import Path

import aiohttp
from aiohttp import web
from nio import (
    AsyncClient,
    InviteMemberEvent,
    LoginResponse,
    MatrixRoom,
    RoomMessageText,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("archiver-bot")

IMDB_RE = re.compile(r"https?://(?:www\.)?imdb\.com/title/(tt\d+)")
TMDB_MOVIE_RE = re.compile(r"https?://(?:www\.)?themoviedb\.org/movie/(\d+)")
TMDB_TV_RE = re.compile(r"https?://(?:www\.)?themoviedb\.org/tv/(\d+)")

JELLYSEERR_URL = os.environ.get("JELLYSEERR_URL", "http://localhost:5055")
JELLYSEERR_API_KEY = os.environ["JELLYSEERR_API_KEY"]
RADARR_API_KEY = os.environ.get("RADARR_API_KEY", "")
SONARR_API_KEY = os.environ.get("SONARR_API_KEY", "")
MATRIX_HOMESERVER = os.environ["MATRIX_HOMESERVER"]
MATRIX_ACCESS_TOKEN = os.environ["MATRIX_ACCESS_TOKEN"]
MATRIX_USER_ID = os.environ.get("MATRIX_USER_ID", "@archiver:lassul.us")
MATRIX_DEVICE_ID = os.environ.get("MATRIX_DEVICE_ID", "ARCHIVER")
STORE_PATH = os.environ.get("STORE_PATH", "/var/lib/archiver-bot")
WEBHOOK_PORT = int(os.environ.get("WEBHOOK_PORT", "8099"))
FLAX_URL = os.environ.get("FLAX_URL", "https://flax.lassul.us")
MEDIA_PATH_PREFIX = os.environ.get("MEDIA_PATH_PREFIX", "/var/download/")

# Persistent tracking of requested media -> rooms
TRACKING_FILE = Path(STORE_PATH) / "tracked_requests.json"


def load_tracked() -> dict:
    """Load tracked requests from disk. Keys are 'movie:TMDBID' or 'tv:TMDBID', values are lists of room_ids."""
    try:
        return json.loads(TRACKING_FILE.read_text())
    except Exception:
        return {}


def save_tracked(tracked: dict):
    """Save tracked requests to disk."""
    TRACKING_FILE.write_text(json.dumps(tracked))


def track_request(media_type: str, tmdb_id: int, room_id: str):
    """Track that a room requested this media."""
    tracked = load_tracked()
    key = f"{media_type}:{tmdb_id}"
    rooms = tracked.get(key, [])
    if room_id not in rooms:
        rooms.append(room_id)
    tracked[key] = rooms
    save_tracked(tracked)


def pop_tracked(media_type: str, tmdb_id: int) -> list[str]:
    """Get and remove tracked rooms for this media."""
    tracked = load_tracked()
    key = f"{media_type}:{tmdb_id}"
    rooms = tracked.pop(key, [])
    save_tracked(tracked)
    return rooms


def make_flax_link(path: str) -> str:
    """Turn a local path like /var/download/movies/Title (Year)/file.mp4 into a flax.lassul.us URL."""
    from urllib.parse import quote
    relative = path
    if relative.startswith(MEDIA_PATH_PREFIX):
        relative = relative[len(MEDIA_PATH_PREFIX):]
    return f"{FLAX_URL}/{quote(relative)}"


async def jellyseerr_request(session: aiohttp.ClientSession, path: str, **kwargs) -> dict:
    """Make an authenticated request to Jellyseerr."""
    headers = {
        "X-Api-Key": JELLYSEERR_API_KEY,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    method = kwargs.pop("method", "GET")
    url = f"{JELLYSEERR_URL}/api/v1{path}"
    async with session.request(method, url, headers=headers, **kwargs) as resp:
        return await resp.json()


async def find_by_imdb(session: aiohttp.ClientSession, imdb_id: str) -> dict | None:
    """Look up a movie or TV show by IMDb ID via Radarr/Sonarr, returning Jellyseerr-compatible data."""

    # Try Radarr (movies) first
    try:
        async with session.get(
            f"http://localhost:7878/api/v3/movie/lookup?term=imdb:{imdb_id}",
            headers={"X-Api-Key": RADARR_API_KEY},
        ) as resp:
            results = await resp.json()
            if results and len(results) > 0:
                tmdb_id = results[0].get("tmdbId")
                title = results[0].get("title", "Unknown")
                year = str(results[0].get("year", ""))
                if tmdb_id:
                    log.info(f"Radarr resolved {imdb_id} -> TMDB {tmdb_id} ({title})")
                    return {
                        "id": tmdb_id,
                        "mediaType": "movie",
                        "title": title,
                        "releaseDate": f"{year}-01-01" if year else "",
                    }
    except Exception as e:
        log.warning(f"Radarr lookup failed: {e}")

    # Try Sonarr (TV shows)
    try:
        async with session.get(
            f"http://localhost:8989/api/v3/series/lookup?term=imdb:{imdb_id}",
            headers={"X-Api-Key": SONARR_API_KEY},
        ) as resp:
            results = await resp.json()
            if results and len(results) > 0:
                tmdb_id = results[0].get("tmdbId", 0)
                title = results[0].get("title", "Unknown")
                year = str(results[0].get("year", ""))
                if tmdb_id:
                    log.info(f"Sonarr resolved {imdb_id} -> TMDB {tmdb_id} ({title})")
                    return {
                        "id": tmdb_id,
                        "mediaType": "tv",
                        "name": title,
                        "firstAirDate": f"{year}-01-01" if year else "",
                    }
    except Exception as e:
        log.warning(f"Sonarr lookup failed: {e}")

    return None


async def lookup_media_path(session: aiohttp.ClientSession, media_type: str, tmdb_id: int) -> str | None:
    """Look up the path for a movie file or show folder from Radarr/Sonarr by TMDB ID."""
    try:
        if media_type == "movie":
            async with session.get(
                f"http://localhost:7878/api/v3/movie?tmdbId={tmdb_id}",
                headers={"X-Api-Key": RADARR_API_KEY},
            ) as resp:
                results = await resp.json()
                if results and len(results) > 0:
                    # Return direct file path if available, otherwise folder
                    movie_file = results[0].get("movieFile", {})
                    if movie_file and movie_file.get("path"):
                        return movie_file["path"]
                    return results[0].get("path") or results[0].get("folderName")
        else:
            async with session.get(
                f"http://localhost:8989/api/v3/series?tvdbId={tmdb_id}",
                headers={"X-Api-Key": SONARR_API_KEY},
            ) as resp:
                results = await resp.json()
                if results and len(results) > 0:
                    return results[0].get("path")
    except Exception as e:
        log.warning(f"Media path lookup failed for {media_type}:{tmdb_id}: {e}")
    return None


async def request_media(session: aiohttp.ClientSession, media: dict, room_id: str) -> tuple[str, str]:
    """Request a movie or TV show via Jellyseerr. Returns (plain, html) status message."""
    media_type = media["mediaType"]
    media_id = media["id"]
    title = media.get("title") or media.get("name") or "Unknown"
    year = (media.get("releaseDate") or media.get("firstAirDate") or "")[:4]
    display = f"{title} ({year})" if year else title

    # Check if already available or requested
    existing = media.get("mediaInfo")
    if existing:
        status = existing.get("status")
        # status 5 = available, 4 = partially available, 3 = processing, 2 = pending
        if status == 5:
            path = await lookup_media_path(session, media_type, media_id)
            if path:
                link = make_flax_link(path)
                return (f"✅ {display} is already available!\n{link}", f'✅ <b>{display}</b> is already available!<br><a href="{link}">{link}</a>')
            return (f"✅ {display} is already available!", f"✅ <b>{display}</b> is already available!")
        elif status in (2, 3, 4):
            track_request(media_type, media_id, room_id)
            return (f"⏳ {display} has already been requested and is being processed.", f"⏳ <b>{display}</b> has already been requested and is being processed.")

    payload = {"mediaType": media_type, "mediaId": media_id}
    if media_type == "tv":
        payload["seasons"] = "all"

    # Check if Radarr/Sonarr already has the file before requesting
    existing_path = await lookup_media_path(session, media_type, media_id)
    if existing_path:
        link = make_flax_link(existing_path)
        # Still send the request to Jellyseerr so it's tracked there too
        await jellyseerr_request(session, "/request", method="POST", json=payload)
        return (f"✅ {display} is already available!\n{link}", f'✅ <b>{display}</b> is already available!<br><a href="{link}">{link}</a>')

    result = await jellyseerr_request(session, "/request", method="POST", json=payload)

    if "id" in result:
        track_request(media_type, media_id, room_id)
        return (f"🎬 Successfully requested {display}! I'll notify you when it's downloaded.", f"🎬 Successfully requested <b>{display}</b>! I'll notify you when it's downloaded.")
    else:
        error = result.get("message", json.dumps(result))
        return (f"❌ Failed to request {display}: {error}", f"❌ Failed to request <b>{display}</b>: {error}")


async def send_notice(client: AsyncClient, room_id: str, plain: str, html: str):
    """Send a notice message to a room."""
    await client.room_send(
        room_id,
        "m.room.message",
        {"msgtype": "m.notice", "body": plain, "format": "org.matrix.custom.html", "formatted_body": html},
    )


async def on_message(client: AsyncClient, room: MatrixRoom, event: RoomMessageText, http: aiohttp.ClientSession):
    """Handle messages in rooms, looking for IMDb/TMDB links."""
    # Ignore our own messages
    if event.sender == client.user_id:
        return

    body = event.body
    log.info(f"Message from {event.sender} in {room.display_name}: {body[:100]}")

    # Help command
    if body.strip().lower() in ("help", "!help"):
        plain = (
            "Archiver Bot\n\n"
            "Send me an IMDb or TMDB link and I'll request the movie/show on Jellyseerr.\n"
            "I'll notify you when the download is complete.\n\n"
            "Examples:\n"
            "  https://www.imdb.com/title/tt0133093/\n"
            "  https://www.themoviedb.org/movie/603\n"
            "  https://www.themoviedb.org/tv/1399"
        )
        html = (
            "<b>Archiver Bot</b><br><br>"
            "Send me an IMDb or TMDB link and I'll request the movie/show on Jellyseerr.<br>"
            "I'll notify you when the download is complete.<br><br>"
            "Examples:<br>"
            "<code>https://www.imdb.com/title/tt0133093/</code><br>"
            "<code>https://www.themoviedb.org/movie/603</code><br>"
            "<code>https://www.themoviedb.org/tv/1399</code>"
        )
        await send_notice(client, room.room_id, plain, html)
        return

    # Collect all media references from the message
    results = []

    for imdb_id in set(IMDB_RE.findall(body)):
        log.info(f"Found IMDb link {imdb_id} in {room.display_name} from {event.sender}")
        media = await find_by_imdb(http, imdb_id)
        if media is None:
            results.append((f"❓ Could not find anything for {imdb_id}.", f"❓ Could not find anything for <code>{imdb_id}</code>."))
        else:
            results.append(await request_media(http, media, room.room_id))

    for tmdb_id in set(TMDB_MOVIE_RE.findall(body)):
        log.info(f"Found TMDB movie link {tmdb_id} in {room.display_name} from {event.sender}")
        media = {"id": int(tmdb_id), "mediaType": "movie"}
        try:
            details = await jellyseerr_request(http, f"/movie/{tmdb_id}")
            media["title"] = details.get("title", "Unknown")
            media["releaseDate"] = details.get("releaseDate", "")
            media["mediaInfo"] = details.get("mediaInfo")
        except Exception as e:
            log.warning(f"Failed to fetch TMDB movie {tmdb_id}: {e}")
        results.append(await request_media(http, media, room.room_id))

    for tmdb_id in set(TMDB_TV_RE.findall(body)):
        log.info(f"Found TMDB TV link {tmdb_id} in {room.display_name} from {event.sender}")
        media = {"id": int(tmdb_id), "mediaType": "tv"}
        try:
            details = await jellyseerr_request(http, f"/tv/{tmdb_id}")
            media["name"] = details.get("name", "Unknown")
            media["firstAirDate"] = details.get("firstAirDate", "")
            media["mediaInfo"] = details.get("mediaInfo")
        except Exception as e:
            log.warning(f"Failed to fetch TMDB TV {tmdb_id}: {e}")
        results.append(await request_media(http, media, room.room_id))

    for plain, html in results:
        await send_notice(client, room.room_id, plain, html)


async def on_invite(client: AsyncClient, room: MatrixRoom, event: InviteMemberEvent):
    """Auto-join rooms when invited."""
    log.info(f"Invite event in {room.room_id}: state_key={event.state_key}, sender={event.sender}, membership={event.membership}, our_id={client.user_id}")
    if event.state_key != client.user_id:
        return
    log.info(f"Joining {room.room_id} (invited by {event.sender})...")
    result = await client.join(room.room_id)
    log.info(f"Join result for {room.room_id}: {result}")


async def handle_radarr_webhook(request):
    """Handle Radarr webhook for download completion."""
    try:
        data = await request.json()
        event_type = data.get("eventType", "")
        log.info(f"Radarr webhook: {event_type}")

        if event_type in ("Download", "MovieFileDelete"):
            movie = data.get("movie", {})
            tmdb_id = movie.get("tmdbId")
            title = movie.get("title", "Unknown")
            year = movie.get("year", "")
            display = f"{title} ({year})" if year else title
            # Prefer the actual movie file path, fall back to folder
            movie_file = data.get("movieFile", {})
            file_path = movie_file.get("path") or movie.get("folderPath", "")

            if event_type == "Download" and tmdb_id:
                rooms = pop_tracked("movie", tmdb_id)
                if rooms:
                    client = request.app["matrix_client"]
                    link = make_flax_link(file_path)
                    plain = f"✅ {display} has been downloaded and is now available!\n{link}"
                    html = f'✅ <b>{display}</b> has been downloaded and is now available!<br><a href="{link}">{link}</a>'
                    for room_id in rooms:
                        try:
                            await send_notice(client, room_id, plain, html)
                        except Exception as e:
                            log.warning(f"Failed to notify room {room_id}: {e}")
    except Exception as e:
        log.exception(f"Error handling Radarr webhook: {e}")

    return web.Response(text="ok")


async def handle_sonarr_webhook(request):
    """Handle Sonarr webhook for download completion."""
    try:
        data = await request.json()
        event_type = data.get("eventType", "")
        log.info(f"Sonarr webhook: {event_type}")

        if event_type in ("Download", "EpisodeFileDelete"):
            series = data.get("series", {})
            tmdb_id = series.get("tmdbId")
            title = series.get("title", "Unknown")
            year = series.get("year", "")
            display = f"{title} ({year})" if year else title

            episodes = data.get("episodes", [])
            ep_info = ""
            if episodes:
                ep_nums = [f"S{ep.get('seasonNumber', 0):02d}E{ep.get('episodeNumber', 0):02d}" for ep in episodes]
                ep_info = f" ({', '.join(ep_nums)})"

            if event_type == "Download" and tmdb_id:
                rooms = pop_tracked("tv", tmdb_id)
                if rooms:
                    client = request.app["matrix_client"]
                    folder_path = series.get("path", "")
                    link = make_flax_link(folder_path)
                    plain = f"✅ {display}{ep_info} has been downloaded and is now available!\n{link}"
                    html = f'✅ <b>{display}</b>{ep_info} has been downloaded and is now available!<br><a href="{link}">{link}</a>'
                    for room_id in rooms:
                        try:
                            await send_notice(client, room_id, plain, html)
                        except Exception as e:
                            log.warning(f"Failed to notify room {room_id}: {e}")
    except Exception as e:
        log.exception(f"Error handling Sonarr webhook: {e}")

    return web.Response(text="ok")


async def run():
    """Main bot loop."""
    client = AsyncClient(
        MATRIX_HOMESERVER,
        MATRIX_USER_ID,
        device_id=MATRIX_DEVICE_ID,
        store_path=STORE_PATH,
    )
    client.access_token = MATRIX_ACCESS_TOKEN
    client.user_id = MATRIX_USER_ID

    http = aiohttp.ClientSession()

    # Do an initial sync BEFORE registering callbacks to skip old messages
    log.info("Performing initial sync...")
    resp = await client.sync(timeout=10000, full_state=True)
    if hasattr(resp, "next_batch"):
        log.info(f"Initial sync complete, next_batch: {resp.next_batch}")
    else:
        log.error(f"Initial sync failed: {resp}")
        await http.close()
        await client.close()
        sys.exit(1)

    # Register event callbacks only after initial sync
    client.add_event_callback(lambda room, event: on_message(client, room, event, http), RoomMessageText)
    client.add_event_callback(lambda room, event: on_invite(client, room, event), InviteMemberEvent)

    # Start webhook server for Radarr/Sonarr notifications
    app = web.Application()
    app["matrix_client"] = client
    app.router.add_post("/webhook/radarr", handle_radarr_webhook)
    app.router.add_post("/webhook/sonarr", handle_sonarr_webhook)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", WEBHOOK_PORT)
    await site.start()
    log.info(f"Webhook server listening on 127.0.0.1:{WEBHOOK_PORT}")

    log.info(f"Bot {MATRIX_USER_ID} is running!")

    try:
        await client.sync_forever(timeout=30000, full_state=True)
    except Exception:
        log.exception("sync_forever crashed")
    finally:
        await runner.cleanup()
        await http.close()
        await client.close()


def main():
    asyncio.run(run())
