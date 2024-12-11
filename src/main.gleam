import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
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
  io.println("Starting the server on port 4221...")
  
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

type Headers {
  Headers(user_agent: Option(String), accept_encoding: Option(String))
}

type StatusCode {
  StatusOk
  Created
  NotFound
}

type Args {
  Args(directory: Option(String))
}

fn load_args() -> Args {
  io.println("Parsing arguments...")
  case argv.load().arguments {
    ["--directory", directory] -> Args(option.Some(directory))
    _ -> {
      io.println("No directory argument provided.")
      Args(option.None)
    }
  }
}

fn parse_headers(header_lines: List(String)) -> Headers {
  io.println("Parsing headers...")
  let user_agent = case
    list.find(header_lines, fn(header) {
      string.starts_with(header, "User-Agent:")
    })
  {
    Ok("User-Agent:" <> user_agent) -> Some(user_agent)
    _ -> None
  }

  let accept_encoding = case
    list.find(header_lines, fn(header) {
      string.starts_with(header, "Accept-Encoding:")
    })
  {
    Ok("Accept-Encoding:" <> accept_encoding) -> Some(accept_encoding)
    _ -> None
  }

  Headers(user_agent: user_agent, accept_encoding: accept_encoding)
}

// Function to handle HTTP requests
fn handle_request(request: BitArray, args: Args) {
  let assert Ok(request_string) = bit_array.to_string(request)
  // Split the request into headers and body
  let assert [request_and_headers, body] = string.split(request_string, "\r\n\r\n")
   // Split headers into individual lines
  let assert [request_line, ..header_lines] =
    string.split(request_and_headers, "\r\n")
  let headers = parse_headers(header_lines)
   // Match the request line
  case string.split(request_line, " ") {
    // Handle /echo/{value} endpoint
    ["GET", "/echo/" <> value, _] -> {
      build_response(value, StatusOk, "text/plain", headers) 
    }
    // Handle /user-agent endpoint
    ["GET", "/user-agent", _] -> {
      let response = case headers.user_agent {
        Some(user_agent) -> user_agent
        _ -> ""
      }
      build_response(response, StatusOk, "text/plain", headers)
    }
    // Handle /file endpoint
    ["GET", "/files/" <> filename, _] -> {
      case args.directory {
        option.Some(directory) -> {
          let path = directory <> filename
          case simplifile.read(path) {
            Ok(file_content) ->
              build_response(file_content,StatusOk, "application/octet-stream", headers)
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
            Ok(_) -> build_response("", Created, "text/plain", headers)
            Error(_) -> build_404()
          }
        }
        _ -> build_404()
      }
    }
    // Handle the root endpoint
    ["GET", "/", _] -> {
      build_response("", StatusOk, "text/plain", headers)
    }
    // Handle all other paths with a 404 response
    _ -> build_404()
  }
}
// Helper function to build a plain text HTTP response
fn build_response(body: String, status_code: StatusCode, content_type: String, request_headers: Headers,) -> String {
  [
    response_line(status_code),
    "Content-Type: " <> content_type,
  ]
  |> append_content_encoding(request_headers)
  |> list.append([""])
  |> string.join("\r\n")
  <> "\r\n" <> body
}

// function to handle content Encoding
fn append_content_encoding(
  response_headers: List(String),
  request_headers: Headers,
) {
  case request_headers {
    Headers(accept_encoding: Some("gzip"), ..) ->
      list.append(response_headers, ["Content-Encoding: gzip"])
    _ -> response_headers
  }
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


