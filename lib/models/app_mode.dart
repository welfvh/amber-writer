// App mode for controller/display setup
// Controller (Mac): edits text, runs WebSocket server
// Display (DC1): mirrors text, runs WebSocket client, input blocked

enum AppMode {
  controller, // Mac - editing device
  display,    // DC1 - display-only mirror
}
