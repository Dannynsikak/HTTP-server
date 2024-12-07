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
fn handle_request(data: BitArray) {
  let assert Ok(data) = bit_array.to_string(data)
  let values = string.split(data, "\r\n")
  let assert Ok(body) = list.first(values)
  case string.split(body, " ") {
    ["GET", "/echo/" <> value, _] -> {
      string.join(
        [
          "HTTP/1.1 200 OK",
          "Content-Type: text/plain",
          "Content-Length: " <> int.to_string(string.length(value)),
          "",
          value,
        ],
        with: "\r\n",
      )
    }
    ["GET", "/", _] -> {
      "HTTP/1.1 200 OK\r\n\r\n"
    }
    _ -> {
      "HTTP/1.1 404 Not Found\r\n\r\n"
    }
  }
}

