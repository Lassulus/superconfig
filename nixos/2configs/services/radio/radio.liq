log.stdout.set(true)

# use yt-dlp
settings.protocol.youtube_dl.path.set("yt-dlp")

## functions

def stringify_attrs(attrs) =
  let json.stringify out = (attrs : [(string * string)] as json.object)
  out
end

def filter_music(req) =
  filename = request.filename(req)
  if string.match(pattern = '.*/\\.graveyard/.*', filename) then
    false
  else
    true
  end
end

def queue_contents(q) =
  list.map(fun (req) -> request.uri(req), q)
end
## main

env = environment()
port = string.to_int(env["RADIO_PORT"], default = 8000)

all_music = playlist(env["MUSIC"], check_next = filter_music)
wishlist = request.queue()
tracks = fallback(track_sensitive = true, [wishlist, all_music])
tracks = blank.eat(tracks)

last_metadata = ref([])
def on_metadata(m) =
  last_metadata := m
  print("changing tracks")
  out = process.read(env["HOOK_TRACK_CHANGE"], env = m, timeout = 5.0)
  print(out)
end
tracks.on_metadata(on_metadata)

# some nice effects
music = crossfade(tracks)
music = mksafe(music)
music = normalize(music)

news = request.queue()
radio = smooth_add(normal = music, special = amplify(1.5, news))

if string.length(env["ICECAST_HOST"]) > 0 then
  output.icecast(host = env["ICECAST_HOST"], mount = '/music.ogg', password = 'hackme', %vorbis(quality = 1), music)
  output.icecast(host = env["ICECAST_HOST"], mount = '/music.mp3', password = 'hackme', %mp3.vbr(), music)
  output.icecast(host = env["ICECAST_HOST"], mount = '/music.opus', password = 'hackme', %opus(bitrate = 128), music)

  output.icecast(host = env["ICECAST_HOST"], mount = '/radio.ogg', password = 'hackme', %vorbis(quality = 1), radio)
  output.icecast(host = env["ICECAST_HOST"], mount = '/radio.mp3', password = 'hackme', %mp3.vbr(), radio)
  output.icecast(host = env["ICECAST_HOST"], mount = '/radio.opus', password = 'hackme', %opus(bitrate = 128), radio)
else
  output(fallible = true, buffer(radio))
end

interactive.harbor(port = port)

def current(~protocol, ~headers, ~data, uri) =
  http.response(content_type = "application/json", data = stringify_attrs(
    !last_metadata
  ))
end
harbor.http.register("/current", port = port, current)

def skip(~protocol, ~headers, ~data, uri) =
  tracks.skip()
  http.response(content_type = "application/json", data = stringify_attrs(
    !last_metadata
  ))
end
harbor.http.register("/skip", method = "POST", port = port, skip)

def all_tracks(~protocol, ~headers, ~data, uri) =
  http.response(content_type = "application/json", data = json.stringify(
    all_music.remaining_files()
  ))
end
harbor.http.register("/all_tracks", port = port, all_tracks)

def wish_track(~protocol, ~headers, ~data, uri) =
  # disallow process:
  if string.match(pattern = '^process:', data) then
    http.response(code = 400)
  else
    # TODO report errors back
    wish = request.create(data)
    wishlist.push(wish)
    http.response(content_type = "application/json", data = "ok")
  end
end
harbor.http.register("/wish", method = "POST", port = port, wish_track)

def wish_tracklist(~protocol, ~headers, ~data, uri) =
  http.response(content_type = "application/json", data = json.stringify(
    queue_contents(wishlist.queue())
  ))
end
harbor.http.register("/wish", port = port, wish_tracklist)

def newsshow(~protocol, ~headers, ~data, uri) =
  news.push(request.create("http://c.r/news.ogg"))
  http.response(content_type = "application/json", data = "ok")
end
harbor.http.register("/newsshow", method = "POST", port = port, newsshow)
