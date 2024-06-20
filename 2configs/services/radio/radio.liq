log.stdout.set(true)

# use yt-dlp
settings.protocol.youtube_dl.path.set("yt-dlp")

# add filenames to metadata
settings.encoder.metadata.export.set(list.append(settings.encoder.metadata.export(), [ "filename" ]))

## functions

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
radio = smooth_add(duration = 0.1, normal = music, special = amplify(1.5, news))

if string.length(env["ICECAST_HOST"]) > 0 then
  output.icecast(host = env["ICECAST_HOST"], mount = '/music.ogg', password = 'hackme', %vorbis(quality = 1), music)
  output.icecast(host = env["ICECAST_HOST"], mount = '/music.mp3', password = 'hackme', %mp3.vbr(), music)
  output.icecast(host = env["ICECAST_HOST"], mount = '/music.opus', password = 'hackme', %opus(bitrate = 128), music)

  output.icecast(host = env["ICECAST_HOST"], mount = '/radio.ogg', password = 'hackme', %vorbis(quality = 1), radio)
  output.icecast(host = env["ICECAST_HOST"], mount = '/radio.mp3', password = 'hackme', %mp3.vbr(), radio)
  output.icecast(host = env["ICECAST_HOST"], mount = '/radio.opus', password = 'hackme', %opus(bitrate = 128), radio)
  output.icecast(host = env["ICECAST_HOST"], mount = '/radio.badge', password = 'hackme', send_icy_metadata = false, %mp3.cbr(bitrate = 64), radio)
else
  output(fallible = true, buffer(radio))
end

interactive.harbor(port = port)

def current(request, response) =
  response.data(metadata.json.stringify(last_metadata()))
end
harbor.http.register(port = port, "/current", current)

def skip(request, response) =
  tracks.skip()
  response.data(metadata.json.stringify(last_metadata()))
end
harbor.http.register(method = "POST", port = port, "/skip", skip)

def all_tracks(request, response) =
  response.data(json.stringify(all_music.remaining_files()))
end
harbor.http.register(port = port, "/all_tracks", all_tracks)

def wish_track(req, response) =
  if string.match(pattern = '^process:', req.body()) then
    response.status_code(400)
  else
    # TODO report errors back
    wish = request.create(req.body())
    wishlist.push(wish)
    response.data("ok")
  end
end
harbor.http.register(method = "POST", port = port, "/wish", wish_track)

def wish_tracklist(request, response) =
  response.data(json.stringify(queue_contents(wishlist.queue())))
end
harbor.http.register(port = port, "/wish", wish_tracklist)

def announce(req, response) =
  news.push(request.create("http://c.r/announce.ogg"))
  response.data("ok")
end
harbor.http.register(method = "POST", port = port, "/announce", announce)

def newsshow(req, response) =
  news.push(request.create("http://c.r/news.ogg"))
  response.data("ok")
end
harbor.http.register(method = "POST", port = port, "/newsshow", newsshow)
