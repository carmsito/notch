let lastSent = { url: "", time: 0, title: "", playing: false };

function getVideoState() {
  const video = document.querySelector("video");
  if (!video) {
    return null;
  }
  return {
    url: window.location.href,
    time: video.currentTime || 0,
    title: document.title || "",
    playing: !video.paused
  };
}

function shouldSend(state) {
  if (!state) return false;
  if (state.url !== lastSent.url) return true;
  if (state.title !== lastSent.title) return true;
  if (state.playing !== lastSent.playing) return true;
  if (Math.abs(state.time - lastSent.time) > 0.75) return true;
  return false;
}

function tick() {
  const state = getVideoState();
  if (!state) return;
  if (!shouldSend(state)) return;

  lastSent = state;
  chrome.runtime.sendMessage({
    type: "video_state",
    payload: {
      url: state.url,
      time: state.time,
      title: state.title
    }
  });
}

setInterval(tick, 1000);
