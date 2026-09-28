// "open in" links for a coordinate; shared by index.html and at.html.
// There is no single url every maps app opens, so offer one per app.
function mapLinks(lat, lon) {
  // iOS has no handler for geo: (iPadOS reports itself as a Mac)
  var ios =
    /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  var ll = lat + "," + lon;
  var links = [
    [
      "Google Maps",
      "https://www.google.com/maps/search/?api=1&query=" +
        encodeURIComponent(ll),
    ],
    ["Apple Maps", "https://maps.apple.com/?ll=" + ll + "&q=lassulus"],
  ];
  // android: app chooser incl. Google Maps, OsmAnd, Organic Maps, ...
  if (!ios)
    links.push(["choose app…", "geo:" + ll + "?q=" + ll + "(lassulus)"]);
  links.push([
    "OpenStreetMap",
    "https://www.openstreetmap.org/?mlat=" +
      lat +
      "&mlon=" +
      lon +
      "#map=16/" +
      lat +
      "/" +
      lon,
  ]);
  return links;
}

function renderMapLinks(container, lat, lon) {
  container.replaceChildren();
  mapLinks(lat, lon).forEach(function (l) {
    var a = document.createElement("a");
    a.textContent = l[0];
    a.href = l[1];
    container.appendChild(a);
  });
}
