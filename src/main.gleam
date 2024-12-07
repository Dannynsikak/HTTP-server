import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/otp/actor
import gleam/string
import glisten
import gleam/bytes_builder
import gleam/bit_array


pub fn main() {
  // Ensures gleam doesn't complain about unused imports in stage 1 (feel free to remove this!)
  let _ = glisten.handler
  let _ = glisten.serve
  let _ = process.sleep_forever
  let _ = actor.continue
  let _ = None
  // You can use print statements as follows for debugging, they'll be visible when running tests.
  io.println("Logs from your program will appear here!")
  // Uncomment this block to pass the first stage
  //
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      io.println("Received message!")
      let assert glisten.Packet(msg) = msg
      let response = handle_request(msg)
      let assert Ok(_) = glisten.send(conn, bytes_builder.from_string(response))
      actor.continue(state)
    })
    |> glisten.serve(4221)
  process.sleep_forever()
}


// Function to handle HTTP requests
fn handle_request(request: BitArray) {
  let assert Ok(request_string) = bit_array.to_string(request)
  // Split the request into headers and body
  let assert [request_and_headers, _body] = string.split(request_string, "\r\n\r\n")
   // Split headers into individual lines
  let assert [request_line, ..header_lines] =
    string.split(request_and_headers, "\r\n")
   // Match the request line
  case string.split(request_line, " ") {
    // Handle /echo/{value} endpoint
    ["GET", "/echo/" <> value, _] -> {
      build_plain_response(value) 
    }
    // Handle /user-agent endpoint
    ["GET", "/user-agent", _] -> {
      let assert Ok("User-Agent: " <> user_agent) =
        list.find(header_lines, fn(header) {
          string.starts_with(header, "User-Agent:")
        })
      build_plain_response(user_agent)
    }
    // Handle the root endpoint
    ["GET", "/", _] -> {
      build_plain_response("")
    }
    // Handle all other paths with a 404 response
    _ -> "HTTP/1.1 404 Not Found\r\n\r\n"
  }
}
// Helper function to build a plain text HTTP response
fn build_plain_response(body: String) -> String {
  [
    "HTTP/1.1 200 OK",
    "Content-Type: text/plain",
    "Content-Length: " <> int.to_string(string.length(body)),
    "",
    body,
  ]
  |> string.join("\r\n")
}

