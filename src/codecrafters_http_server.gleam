import gleam/bytes_tree
import gleam/dict.{type Dict}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import gleam/yielder
import logging
import mist.{type Connection, type ResponseData}

@external(erlang, "logger", "update_primary_config")
fn logger_update_primary_config(config: Dict(Atom, Atom)) -> Result(Nil, any)

/// the default HTML page to be served
const index = "<html lang='en'>
  <head>
    <title>HTTP SERVER</title>
  </head>
  <body>
    Hello, world!
  </body>
</html>"

/// entry point to the application
pub fn main() {
  logging.configure()

  // set the logger configuration to debug level
  let _ =
    logger_update_primary_config(
      dict.from_list([
        #(atom.create_from_string("level"), atom.create_from_string("debug")),
      ]),
    )
  // initialize selector and state for websocket handling
  let selector = process.new_selector()
  let state = Nil

  // define a 404 not found response
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))

  // start the HHTP server with request handling
  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      // log incomig requests
      logging.log(
        logging.Info,
        "Got a request from: " <> string.inspect(mist.get_client_info(req.body)),
      )

      // extract useful headers for logging purpose
      let user_agent = request.get_header(req, "User-Agent")
      let accept_encoding = request.get_header(req, "Accept-Encoding")
      // handle different request paths
      case request.path_segments(req) {
        // serve the default index page
        [] ->
          response.new(200)
          |> response.prepend_header("User-Agent", result.unwrap(user_agent,"Unknown"))
          |> response.prepend_header("Accept-Encoding", result.unwrap(accept_encoding,"Unknown"))
          |> response.set_body(mist.Bytes(bytes_tree.from_string(index)))
        // initialize a websocket connection
        ["ws"] ->
          mist.websocket(
            request: req,
            on_init: fn(_conn) { #(state, Some(selector)) },
            on_close: fn(_state) { io.println("goodbye!") },
            handler: handle_ws_message,
          )
        // handle echo endpoint
        ["echo"] -> echo_body(req)
        // serve chunked data
        ["chunk"] -> serve_chunk(req)
        // serve file based on paths segments
        ["file", ..rest] -> serve_file(req, rest)
        // handle form data submission
        ["form"] -> handle_form(req)

        // fallback for undefined routes
        _ -> not_found
      }
    }
    |> mist.new
    |> mist.bind("localhost") // bind the server to localhost
    |> mist.with_ipv6         // enable IPv6 support
    |> mist.port(4000)           // changed to manually run at 4000
    |> mist.start_http        // start the HTTP server
  // keep the process alive indefinitely
  process.sleep_forever()
}
// message type
pub type MyMessage {
  Broadcast(String)
}
/// websocket message handler
fn handle_ws_message(state, conn, message) {
  case message {
    // respond to "ping" messages with "pong"
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(state)
    }
    // handle other text or binary messages
    mist.Text(_) | mist.Binary(_) -> {
      actor.continue(state)
    }
    // broadcast custom messages to websocket clients
    mist.Custom(Broadcast(text)) -> {
      let assert Ok(_) = mist.send_text_frame(conn, text)
      actor.continue(state)
    }
    // handle websocket closure
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
  }
}
/// echoes the body of the request back to the client
fn echo_body(request: Request(Connection)) -> Response(ResponseData) {
  let content_type =
    request
    |> request.get_header("content-type")
    |> result.unwrap("text/plain")
  // read and return the body of the request
  mist.read_body(request, 1024 * 1024 * 10) // read up to 10 MB
  |> result.map(fn(req) {
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.from_bit_array(req.body)))
    |> response.set_header("content-type", content_type)
  })
  |> result.lazy_unwrap(fn() {
    response.new(400) // return 400 bad request if reading fails
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })
}
/// serves data in chunk
fn serve_chunk(_request: Request(Connection)) -> Response(ResponseData) {
  // create an iterator that saves data with a delay
  let iter =
    [
    "owner: ofonime_nsikak45 email: nsikakdanny11@gmail.com"
    ]
    |> yielder.from_list
    |> yielder.map(fn(data) {
      process.sleep(2000) // simulate delay between chunks
      data
    })
    |> yielder.map(bytes_tree.from_string)
  // return the chunked response
  response.new(200)
  |> response.set_body(mist.Chunked(iter))
  |> response.set_header("content-type", "text/plain")
}
/// serves a requested file 
fn serve_file(
  _req: Request(Connection),
  path: List(String),
) -> Response(ResponseData) {
  let file_path = string.join(path, "/")

  // attempt to send the file 
  mist.send_file(file_path, offset: 0, limit: None)
  |> result.map(fn(file) {
    let content_type = guess_content_type(file_path)
    response.new(200)
    |> response.prepend_header("content-type", content_type)
    |> response.set_body(file)
  })
  |> result.lazy_unwrap(fn() {
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })
}
/// handles form submission
fn handle_form(req: Request(Connection)) -> Response(ResponseData) {
  // read the form data from the request body
  let _req = mist.read_body(req, 1024 * 1024 * 30)
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.new()))
}
/// guesses the content type of the file based on its path
fn guess_content_type(_path: String) -> String {
  "application/octet-stream"
}