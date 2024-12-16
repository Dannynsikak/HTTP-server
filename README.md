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
   gleam --version
   Install project dependencies:

gleam deps download
Compile the project:

gleam build
Running the Server
Start the server by running the compiled executable:

gleam run
By default, the server runs on http://localhost with an automatically assigned port.

## Endpoints

Endpoint Description
/ Serves a static HTML page.
/ws WebSocket endpoint. Handles ping messages.
/echo Echoes back the request body.
/chunk Streams chunked responses with delays.
/file/{path} Serves a file from the specified path.
/form Processes form submissions with large bodies.
WebSocket Example
Connect to the WebSocket endpoint (/ws) using tools like websocat or any WebSocket client:

websocat ws://localhost:PORT/ws
Send "ping": The server responds with "pong".
Send any text or binary data: The server processes and ignores it.
File Serving Example
Request a file:
curl http://localhost:PORT/file/path/to/file.txt
Chunked Responses Example
Stream chunked responses:

curl http://localhost:PORT/chunk
The server streams the response "one", "two", and "three" with 2-second intervals.

Logs
Logs are displayed on the console, showing request details and server events.

Future Improvements
Add more robust error handling and validation.
Support additional HTTP methods like POST, PUT, and DELETE.
Implement more WebSocket features, such as broadcasting to multiple clients.
Contributing
Contributions are welcome! Feel free to submit an issue or pull request.
