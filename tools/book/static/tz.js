// Show times in the visitor's zone: add ?tz= once; every link carries it on.
(function () {
  if (!document.body.dataset.tzaware) return;
  var url = new URL(location.href);
  if (url.searchParams.has("tz")) return;
  var tz;
  try {
    tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
  } catch (e) {
    return;
  }
  if (!tz) return;
  url.searchParams.set("tz", tz);
  location.replace(url.toString());
})();
