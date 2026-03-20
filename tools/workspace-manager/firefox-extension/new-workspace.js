document.getElementById("name").addEventListener("keydown", (e) => {
  if (e.key === "Enter") {
    const name = e.target.value.trim();
    if (name) {
      browser.runtime.sendMessage({
        action: "sendToNewWorkspace",
        workspace: name,
      });
    }
    window.close();
  } else if (e.key === "Escape") {
    window.close();
  }
});
