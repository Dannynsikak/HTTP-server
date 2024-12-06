import gleam/io
import gleam/bytes_builder as bb
import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import gleam/string
import glisten.{Packet}

pub fn main() {
  // Start the HTTP server
  io.println("Starting HTTP server...")

  let assert Ok(_) =
    glisten.handler(
      fn(_conn) { #(Nil, None) },
      fn(msg, state, conn) {
        // Parse the incoming message
        let assert Packet(bit_array) = msg
        io.println("Received message: " <> string.inspect(bit_array))

        // Process the request and generate a response
        let response = handle_request(bit_array)

        // Send the response back
        let assert Ok(_) = glisten.send(conn, bb.from_string(response))

        // Continue processing other messages
        actor.continue(state)
      }
    )
    |> glisten.serve(4221)

  // Keep the process alive
  process.sleep_forever()
}

// Function to handle HTTP requests
fn handle_request(msg: BitArray) -> String {
  case msg {
    <<"GET / HTTP/1.1\r\n":utf8, _rest:bits>> -> {
      "HTTP/1.1 200 OK\r\n\r\n"
    }
    _ -> {
      "HTTP/1.1 404 Not Found\r\n\r\n"
    }
  }
}
