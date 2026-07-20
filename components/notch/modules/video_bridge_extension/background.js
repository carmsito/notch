let port = null;
let portBusy = false;

function connectNative() {
  if (port) {
    return port;
  }
  try {
    port = chrome.runtime.connectNative("com.videoisland.bridge");
    port.onDisconnect.addListener(() => {
      port = null;
    });
  } catch (e) {
    port = null;
  }
  return port;
}

function sendToNative(payload) {
  const p = connectNative();
  if (!p || portBusy) {
    return;
  }
  try {
    portBusy = true;
    p.postMessage(payload);
    // Release busy after a short delay to avoid flooding
    setTimeout(() => {
      portBusy = false;
    }, 200);
  } catch (e) {
    portBusy = false;
  }
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg || msg.type !== "video_state") {
    return;
  }
  sendToNative(msg.payload);
});
