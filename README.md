# Gleam HTTP and WebSocket Server

This project is an HTTP and WebSocket server built using [Gleam](https://gleam.run) and the [Mist](https://hex.pm/packages/mist) library. It demonstrates handling HTTP requests, WebSocket connections, file serving, and form processing.

## Features

- **HTTP Server**:

  - Serve static HTML content.
  - Process form submissions with body parsing.
  - Echo back request bodies with correct `Content-Type`.

- **WebSocket Support**:

  - Upgrade HTTP connections to WebSockets.
  - Respond to WebSocket messages like `ping` with `pong`.
  - Broadcast messages to WebSocket clients.

- **Dynamic File Serving**:

  - Serve files based on the request path.
  - Dynamically determine file `Content-Type`.

- **Chunked Responses**:

  - Stream responses to clients in chunks with simulated delays.

- **Logging**:

  - Logs client request details and server activity.

- **Error Handling**:
  - Gracefully handles invalid routes and file not found errors.

## Installation

1. Ensure you have **Gleam** installed:
You can the check the **Gleam Docs https://gleam.run/getting-started/installing/ ** for installation guide.

gleam --version
# Install project dependencies:

gleam deps download
# Compile the project:

gleam build
# Running the Server
Start the server by running the compiled executable:

gleam run
By default, the server runs on http://localhost with an automatically assigned port.
Feel free to manually assign a port if needed.

## Endpoints

# Endpoint Description

/ Serves a static HTML page.
/ws WebSocket endpoint. Handles ping messages.
/echo Echoes back the request body.
/chunk Streams chunked responses with delays.
/file/{path} Serves a file from the specified path.
/form Processes form submissions with large bodies.

# WebSocket Example
Connect to the WebSocket endpoint (/ws) using tools like Chromebrowser or any WebSocket client:
open the Chrome browser.

Open the Developer Tools (Ctrl + Shift + I / Cmd + Option + I).

Go to the Console tab.

Paste the following JavaScript code to open a WebSocket connection:

const socket = new WebSocket("ws://localhost:PORT/ws");

socket.addEventListener("open", function () {
  console.log("WebSocket connection established.");
  socket.send("ping"); // Send 'ping' message to server
});

socket.addEventListener("message", function (event) {
  console.log("Message from server:", event.data);
});

socket.addEventListener("close", function () {
  console.log("WebSocket connection closed.");
});
Expected Behavior:

When connected, the console logs:

**WebSocket connection established**.
# The server responds with:

Message from server: pong
# Send a custom message:

socket.send("Hello, server!");
The server ignores this since it doesn’t handle arbitrary messages, but it continues.
Close the WebSocket connection:

socket.close();
# Logs:

WebSocket connection closed.

# File Serving Example
Request a file:
curl http://localhost:PORT/file/path/to/file.txt
Chunked Responses Example
# Stream chunked responses:

curl http://localhost:PORT/chunk
The server streams the response "one", "two", and "three" with 2-second intervals.

# Logs
Logs are displayed on the console, showing request details and server events.

# Future Improvements
Support additional HTTP methods like POST, PUT, and DELETE.
Contributing
Contributions are welcome! Feel free to submit an issue or pull request.
