section .data
    ; JSON response with newline as part of the body
    json_response db '{"message":"Welcome to the Assembly Server!"}', 0x0A
    json_len equ $ - json_response  ; Total length: 46 bytes

    response_header db "HTTP/1.1 200 OK", 0x0D, 0x0A; r/n/
                   db "Content-Type: application/json", 0x0D, 0x0A
                   db "Content-Length: "
    response_header_len equ $ - response_header

    ; Buffer for dynamic content length (enough space for largest possible number)
    content_length_buffer db "000", 0x0D, 0x0A, 0x0D, 0x0A
    content_length_part_len equ 7  ; Length of "000\r\n\r\n"

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
    xor rdx, rdx         ; Protocol (0 = default TCP)
    syscall

    ; Check for error
    cmp rax, 0
    jl error_exit

    mov r12, rax         ; Save server socket fd in r12

    ; Enable SO_REUSEADDR to allow reuse of local addresses
    mov rdi, r12         ; socket file descriptor
    mov rsi, 2           ; SOL_SOCKET
    mov rdx, 2           ; SO_REUSEADDR option
    mov rcx, 1           ; option value (true)
    mov r10, 9           ; __NR_setsockopt (64-bit system)
    mov rax, r10
    syscall

    ; Bind socket
    mov rdi, r12         ; server socket fd
    lea rsi, [rel addr]  ; pointer to sockaddr_in structure
    mov rdx, 16          ; size of sockaddr_in
    mov rax, 49          ; sys_bind (fd, sockaddr, addrlen)
    syscall

    ; Check for error
    cmp rax, 0
    jl error_exit

    ; Listen on socket
    mov rdi, r12         ; server socket fd
    mov rsi, 5           ; backlog (max pending connections)
    mov rax, 50          ; sys_listen (fd, backlog)
    syscall

    ; Check for error
    cmp rax, 0
    jl error_exit

accept_loop:
    ; Accept connection
    mov rdi, r12         ; server socket fd
    xor rsi, rsi         ; NULL for client addr (don't store client address)
    xor rdx, rdx         ; NULL for addrlen (don't store address length)
    mov rax, 43          ; sys_accept (sockfd, addr, addrlen)
    syscall

    ; Check for error
    cmp rax, 0
    jl accept_loop       ; On error, continue to next iteration

    mov [client_fd], rax ; Save client socket fd

    ; Calculate content length dynamically
    mov rax, json_len    ; Load the length of JSON response
    call int_to_string   ; Convert to string and store in content_length_buffer

    ; Send HTTP response headers
    mov rdi, [client_fd] ; client socket fd
    lea rsi, [rel response_header] ; pointer to response headers
    mov rdx, response_header_len ; length of response headers
    mov rax, 1           ; sys_write (fd, buf, count)
    syscall

    ; Send Content-Length header (now dynamically calculated)
    mov rdi, [client_fd] ; client socket fd
    lea rsi, [rel content_length_buffer] ; pointer to content length value
    mov rdx, content_length_part_len ; length of content length (always 7 chars: "XXX\r\n\r\n")
    mov rax, 1           ; sys_write
    syscall

    ; Send JSON body (includes the newline)
    mov rdi, [client_fd] ; client socket fd
    lea rsi, [rel json_response] ; pointer to JSON body (includes newline)
    mov rdx, json_len    ; length of JSON body (includes newline)
    mov rax, 1           ; sys_write
    syscall

    ; Close client socket
    mov rdi, [client_fd] ; client socket fd
    mov rax, 3           ; sys_close (fd)
    syscall

    jmp accept_loop      ; Repeat to accept new connections

; Helper function to calculate string length
strlen:
    push rdi
    push rcx
    push rax
    mov rcx, 0xFFFFFFFFFFFFFFFF  ; Max length
    xor al, al                   ; Search for null terminator
    repne scasb                  ; Scan string for null
    not rcx                      ; Invert counter
    dec rcx                      ; Adjust for extra decrement
    mov rax, rcx                 ; Return length in rax
    pop rax
    pop rcx
    pop rdi
    ret

; Helper to convert integer to string
int_to_string:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    lea rdi, [rel content_length_buffer]  ; Target buffer
    mov byte [rdi], '0'  ; Initialize hundreds digit to '0'
    mov byte [rdi+1], '0' ; Initialize tens digit to '0'
    mov byte [rdi+2], '0' ; Initialize units digit to '0'

    ; Handle special case of 0
    test rax, rax
    jnz convert_normal
    jmp convert_done

convert_normal:
    ; Calculate hundreds digit (divide by 100)
    mov rbx, 100
    mov rdx, 0           ; Clear rdx before division
    div rbx              ; Divide rax by 100, quotient in rax, remainder in rdx
    add al, '0'          ; Convert quotient to ASCII
    mov [rdi], al        ; Store hundreds digit
    mov rax, rdx         ; Move remainder to rax for next division

    ; Calculate tens digit (divide by 10)
    mov rbx, 10
    mov rdx, 0           ; Clear rdx before division
    div rbx              ; Divide rax by 10, quotient in rax, remainder in rdx
    add al, '0'          ; Convert quotient to ASCII
    mov [rdi+1], al      ; Store tens digit

    ; Units digit is now in rdx
    add dl, '0'          ; Convert remainder to ASCII
    mov [rdi+2], dl      ; Store units digit

convert_done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

error_exit:
    ; Simple error handling - exit with code 1
    mov rax, 60          ; sys_exit
    mov rdi, 1           ; exit status 1
    syscall
