section .data
    json_response db '{"message":"Welcome to the Assembly Server!"}', 0x0A
    json_len equ $ - json_response

    response db "HTTP/1.1 200 OK", 0x0D, 0x0A; r/n/
            db "Content-Type: application/json", 0x0D, 0x0A
            db "Content-Length: " 
    response_len equ $ - response

    content_length db "46", 0x0D, 0x0A, 0x0D, 0x0A ; "45" is the length of json_response + 1 newline
    content_length_len equ $ - content_length

    addr:
      dw 2              ; AF_INET
      dw 0x901F         ; Port 8080 in network byte order (0x1F90 swapped to 0x901F)
      dd 0x00000000     ; 0.0.0.0 in hex (INADDR_ANY - bind to all interfaces)
      dq 0x0000000000000000

section .bss
    client_fd resq 1

section .text
global _start

_start:
    ; Create socket
    mov rax, 41          ; sys_socket (AF_INET, SOCK_STREAM, 0)
    mov rdi, 2           ; AF_INET
    mov rsi, 1           ; SOCK_STREAM
    xor rdx, rdx         ; Protocol
    syscall

    mov r12, rax         ; Save server socket fd in r12

    ; Bind socket
    mov rdi, r12       ; server socket fd
    lea rsi, [rel addr]  ; pointer to sockaddr_in
    mov rdx, 16          ; size of sockaddr_in
    mov rax, 49          ; sys_bind (fd, sockaddr, addrlen)
    syscall

    ; Listen on socket
    mov rdi, r12         ; server socket fd
    mov rsi, 5           ; backlog
    mov rax, 50          ; sys_listen (fd, backlog)
    syscall

accept_loop:
    ; Accept connection
    mov rdi, r12         ; server socket fd
    xor rsi, rsi         ; NULL for client addr
    xor rdx, rdx         ; NULL for addrlen
    mov rax, 43          ; sys_accept
    syscall

    mov [client_fd], rax ; Save client socket fd

    ; Send HTTP response
    mov rdi, [client_fd] ; client socket fd
    lea rsi, [rel response] ; pointer to response headers
    mov rdx, response_len ; length of response headers
    mov rax, 1           ; sys_write
    syscall

    ; Send Content-Length
    mov rdi, [client_fd] ; client socket fd
    lea rsi, [rel content_length] ; pointer to content length
    mov rdx, content_length_len ; length of content length
    mov rax, 1           ; sys_write
    syscall

    ; Send JSON body
    mov rdi, [client_fd] ; client socket fd
    lea rsi, [rel json_response] ; pointer to JSON body
    mov rdx, json_len    ; length of JSON body
    mov rax, 1           ; sys_write
    syscall

    ; Close client socket
    mov rdi, [client_fd] ; client socket fd
    mov rax, 3           ; sys_close
    syscall

    jmp accept_loop      ; Repeat to accept new connections
