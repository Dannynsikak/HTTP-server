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
import simplifile
import argv


pub fn main() {
  // Ensures gleam doesn't complain about unused imports in stage 1 (feel free to remove this!)
  let _ = glisten.handler
  let _ = glisten.serve
  let _ = process.sleep_forever
  let _ = actor.continue
  let _ = None
  let args = load_args()
  // You can use print statements as follows for debugging, they'll be visible when running tests.
  io.println("Logs from your program will appear here!")
  
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      io.println("Received message!")
      let assert glisten.Packet(msg) = msg
      let response = handle_request(msg, args)
      let assert Ok(_) = glisten.send(conn, bytes_builder.from_string(response))
      actor.continue(state)
    })
    |> glisten.serve(4221)
  process.sleep_forever()
}

type StatusCode {
  StatusOk
  Created
  NotFound
}

type Args {
  Args(directory: option.Option(String))
}

fn load_args() -> Args {
  case argv.load().arguments {
    ["--directory", directory] -> Args(option.Some(directory))
    _ -> Args(option.None)
  }
}

// Function to handle HTTP requests
fn handle_request(request: BitArray, args: Args) {
  let assert Ok(request_string) = bit_array.to_string(request)
  // Split the request into headers and body
  let assert [request_and_headers, body] = string.split(request_string, "\r\n\r\n")
   // Split headers into individual lines
  let assert [request_line, ..header_lines] =
    string.split(request_and_headers, "\r\n")
   // Match the request line
  case string.split(request_line, " ") {
    // Handle /echo/{value} endpoint
    ["GET", "/echo/" <> value, _] -> {
      build_response(value, StatusOk, "text/plain") 
    }
    // Handle /user-agent endpoint
    ["GET", "/user-agent", _] -> {
      let assert Ok("User-Agent: " <> user_agent) =
        list.find(header_lines, fn(header) {
          string.starts_with(header, "User-Agent:")
        })
      build_response(user_agent, StatusOk, "text/plain")
    }
    // Handle /file endpoint
    ["GET", "/files/" <> filename, _] -> {
      case args.directory {
        option.Some(directory) -> {
          let path = directory <> filename
          case simplifile.read(path) {
            Ok(file_content) ->
              build_response(file_content,StatusOk, "application/octet-stream")
            Error(_) -> build_404()
          }
        }
        _ -> build_404()
      }
    }
    // Handle the post endpoint
    ["POST", "/files/" <> filename, _] -> {
      case args.directory {
        option.Some(directory) -> {
          let path = directory <> filename
          case simplifile.write(path, body) {
            Ok(_) -> build_response("", Created, "text/plain")
            Error(_) -> build_404()
          }
        }
        _ -> build_404()
      }
    }
    // Handle the root endpoint
    ["GET", "/", _] -> {
      build_response("", StatusOk, "text/plain")
    }
    // Handle all other paths with a 404 response
    _ -> build_404()
  }
}
// Helper function to build a plain text HTTP response
fn build_response(body: String, status_code: StatusCode, content_type: String) -> String {
  [
    response_line(status_code),
    "Content-Type: " <> content_type,
    "Content-Length: " <> int.to_string(string.length(body)),
    "",
    body,
  ]
  |> string.join("\r\n")
}
// function to handle error
fn build_404() -> String {
  response_line(NotFound) <> "\r\n\r\n"
}

// function to handle response_line
fn response_line(status_code: StatusCode) -> String {
  case status_code {
    StatusOk -> "HTTP/1.1 200 OK"
    Created -> "HTTP/1.1 201 Created"
    NotFound -> "HTTP/1.1 404 Not Found"
  }
}


