import gleam/erlang/process
import gleam/int
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

// Helper function to parse multipart form data
// Helper function to parse multipart form data
fn parse_multipart_form_data(body: BitArray) -> Result(BitArray, String) {
  // Convert body from BitArray to string for easier manipulation
  let assert Ok(body_string) = bit_array.to_string(body)
  
  // Extract the boundary from the Content-Type header
  let boundary = case string.split(body_string, "\r\n") {
    [headers_line | _] -> extract_boundary(headers_line)
    _ -> ""
  }

  // If no boundary is found, return an error
  case boundary {
    "" -> Error("Boundary not found in Content-Type header")
    _ -> {
      // Split the body by the boundary
      let parts = string.split(body_string, "--" <> boundary)

      // Process each part
      let result = parse_parts(parts)

      // Return the parsed data
      case result {
        Ok(parsed_data) -> Ok(parsed_data)
        Error(msg) -> Error(msg)
      }
    }
  }
}

// Helper function to extract the boundary from the Content-Type header
fn extract_boundary(header: String) -> String {
  case string.split(header, "boundary=") {
    [_, boundary] -> boundary
    _ -> ""
  }
}

// Helper function to parse each part of the multipart body
fn parse_parts(parts: List(String)) -> Result(BitArray, String) {
  // Loop through each part, extracting headers and body
  let part_data = list.map(parts, fn(part) {
    case string.split(part, "\r\n\r\n") {
      [header_line, body] -> {
        let headers = parse_headers(header_line)
        case headers {
          Ok(parsed_headers) -> {
            case string.contains(parsed_headers, "Content-Disposition: form-data") {
              True -> Ok(body) // Extract file content
              False -> Error("Invalid part")
            }
          }
          _ -> Error("Failed to parse headers")
        }
      }
      _ -> Error("Invalid part format")
    }
  })
  
  // Combine all the parts into a single BitArray (you can modify this logic based on your needs)
  case list.filter(part_data, fn(data) { data != Error }) {
    Ok(body_parts) -> Ok(list.concat(body_parts))
    _ -> Error("Failed to parse multipart data")
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
      // Handle the multipart form data here
      case parse_multipart_form_data(body) {
        Ok(file_content) -> 
          case simplifile.write(path, file_content) {
            Ok(_) -> build_response("", Created, "text/plain", headers)
            Error(_) -> build_404()
          }
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
    "Content-Length: " <> int.to_string(string.length(body)),
  ]
  |> append_content_encoding(request_headers)
  |> list.append([" ", body])
  |> io.debug
  |> string.join("\r\n")
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


