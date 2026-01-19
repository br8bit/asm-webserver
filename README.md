# Assembly Webserver

A simple HTTP webserver written entirely in x86-64 assembly language that responds with a JSON message.

## Description

This project implements a basic HTTP server in pure assembly language using Linux system calls. The server listens on port 8080 and responds to all requests with a JSON message: `{"message":"Welcome to the Assembly Server!"}`.

## Architecture

The server uses the following Linux system calls:
- `socket()` - Creates a TCP socket
- `bind()` - Binds the socket to a local address and port
- `listen()` - Puts the socket in listening mode
- `accept()` - Accepts incoming connections
- `write()` - Sends HTTP response to clients
- `close()` - Closes client connections

## Key Features

- Pure x86-64 assembly implementation
- HTTP/1.1 compliant responses
- JSON response body
- Proper Content-Length header
- Continuous operation (accepts multiple connections)

## Prerequisites

- Linux system with x86-64 architecture
- NASM (Netwide Assembler)
- GNU linker (ld) - Usually comes with GCC installation
- Podman or Docker (for containerized execution)

## Building and Running

### Method 1: Native Compilation (Linux)

1. Install `NASM`

2. Assemble and link the server:
   ```bash
   nasm -f elf64 server.asm -o server.o
   ld server.o -o server
   chmod +x server
   ```

3. Run the server (requires root to bind to port 8080):
   ```bash
   sudo ./server
   ```

### Method 2: Containerized Execution with Docker/Podman

1. Build the container:
   ```bash
   podman build -t asm-webserver .
   ```

2. Compile the server in the container:
   ```bash
   podman run -it --rm -v $(pwd):/workspace asm-webserver sh -c "nasm -f elf64 server.asm -o server.o && ld server.o -o server && chmod +x server"
   ```

3. Run the server:
   ```bash
   podman run -d --name asm-server -v $(pwd):/workspace -w /workspace -p 8080:8080 asm-webserver sh -c "./server"
   ```

### Method 3: Using Docker Compose (Easiest)

1. Make sure you have Docker or Podman with docker-compose installed

2. Run the server with a single command:
   ```bash
   docker-compose up
   ```

   Or with Podman:
   ```bash
   podman-compose up
   ```

   Note: If using Podman, you may need to install podman-docker compatibility layer.

## Testing

Once the server is running, test it with curl:

```bash
curl http://localhost:8080
```

Expected response:
```
{"message":"Welcome to the Assembly Server!"}
```

Or use a browser to navigate to `http://localhost:8080`

