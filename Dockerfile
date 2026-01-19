FROM alpine:latest

# Install necessary packages
RUN apk add --no-cache \
    nasm \
    build-base

WORKDIR /workspace

# Copy assembly files
COPY . /workspace/

# Compile the assembly code during build
RUN nasm -f elf64 server.asm -o server.o && \
    ld server.o -o server && \
    chmod +x server

# Run the server when container starts
CMD ["./server"]
