## A simple server application

### Basic data structures for http communication

```
type Server struct {
	// Addr ("host:port") : specifies the TCP address of the server
	Addr string
	// DocRoot the root folder under which clients can potentially look up information.
	// Anything outside this should be "out-of-bounds"
	DocRoot string
}

type Request struct {
	Method string // e.g. "GET"
}

type Response struct {
	StatusCode int    // e.g. 200 / 405
	Proto string	  // HTTP/1.1
	FilePath string   // For this application, we will hard-code this to whatever contents are available in "hello-world.txt"
}

```

```
func (s *Server) ListenAndServe() error {}
```

[The ListenAndServe from net/http](https://pkg.go.dev/net/http#ListenAndServe)

### Implementing ListenAndServe

First, we validate whether the server is set up properly. In this example, we just need to see whether
the doc root is correctly set up or not.

os.Stat : returns the FileInfo structure describing file <br/>
[os.IsNotExist](https://pkg.go.dev/os#IsNotExist)

```go
// Validating the doc root of the server
fi, err := os.Stat(s.DocRoot)

if os.IsNotExist(err) {
    return err
}

if !fi.IsDir() {
    return fmt.Errorf("doc root %q is not a directory", s.DocRoot)
}

return nil
```

```go
// server should now start to listen on the configured address
ln, err := net.Listen("tcp", s.Addr)
if err != nil {
    return err
}
fmt.Println("Listening on", ln.Addr())
```

start accepting connections

```go
// accept connections forever
for {
    conn, err := ln.Accept()
    if err != nil {
    continue
    }
    fmt.Println("accepted connection", conn.RemoteAddr())
    go s.HandleConnection(conn)
}
```

### Implementing HandleConnection

Set timeout for every Read operation

```go
conn.SetReadDeadline(time.Now().Add(5 * time.Second))
```

Read next request from the client

```go
req, err := ReadRequest(br)
```

### Implementing ReadRequest

Read the start line of the Request
We'll use the handy method `func ReadLine(br *bufio.Reader) (string, error)` from util.go
for this.

Parse the request line read and do relevant checks
Example : "GET /foo HTTP/1.1" --> ["GET", "/foo HTTP/1.1"] <br/>
[strings.SplitN](https://pkg.go.dev/strings#SplitN)

```go
fields := strings.SplitN(line, " ", 2)
if len(fields) != 2 {
return "", fmt.Errorf("could not parse the request line, got fields %v", fields)
}
return fields[0], nil
```

Read the remaining lines from the request until we get an EOF.

### Back to HandleConnection

Check for the error that ReadRequest returns. It could be the case that

- The client has closed the connection `errors.Is(err, io.EOF)`
- Timeout has happened `err.Timeout()`
- The request from the client is invalid in which case we call `HandleBadRequest`

If all goes well, and we get a proper `Request` object from `ReadRequest`,
we call `HandleGoodRequest`

Here, this we'll not close the connection and handle as many requests for this
connection and pass on the responsibility of maintaining sanity of waiting to the timeout
mechanism.

### Using curl and breakpoint-based debugging of the application

1. Successful GET request

```
╰─ curl -v localhost:8090                                                                                                                                                                                                  ─╯
*   Trying ::1:8090...
* Connection failed
* connect to ::1 port 8090 failed: Connection refused
*   Trying 127.0.0.1:8090...
* Connected to localhost (127.0.0.1) port 8090 (#0)
> GET / HTTP/1.1
> Host: localhost:8090
> User-Agent: curl/7.71.1
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Hello, world!
```

2. Unacceptable HTTP verb

```
╰─ curl -v -XPOST localhost:8090                                                                                                                                                                                           ─╯
*   Trying ::1:8090...
* Connection failed
* connect to ::1 port 8090 failed: Connection refused
*   Trying 127.0.0.1:8090...
* Connected to localhost (127.0.0.1) port 8090 (#0)
> POST / HTTP/1.1
> Host: localhost:8090
> User-Agent: curl/7.71.1
> Accept: */*
>
* Mark bundle as not supporting multiuse
  < HTTP/1.1 405 Method Not Allowed
```

3. Timeout initiated by the server

4. Connection closed by the `curl` client, io.EOF on the server

PS : Link to the Goland IDE is [here](https://www.jetbrains.com/go/). Check it out if you want, it's pretty cool!
Also, if you're interested see [Breakpoints in VSCode for go](https://github.com/golang/vscode-go/blob/master/docs/debugging.md)
