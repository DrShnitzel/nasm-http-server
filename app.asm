global _start

;; Data definitions
struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .data
    file_path db "index.html", 0

    file_read_err_msg db "Failed to read file", 0x0a, 0
    file_read_err_msg_len equ $ - file_read_err_msg

    socket_err_msg db "Failed to open socket", 0x0a, 0
    socket_err_msg_len equ $ - file_read_err_msg

    ; TODO: Take headers from .data, not from file
    ; http_headers db "HTTP/1.1 200 OK", 0xD,0xA "Content-Type: text/html", 0x3B, "charset=utf-8", 0xD,0xA 'Connection: close', 0xD,0xA,0xD,0xA  
    ; http_headers_len equ $ - http_headers

    ;; sockaddr_in structure is passed as parametr to sys_bind 
    pop_sa istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2 ; AF_INET
        at sockaddr_in.sin_port, dw 0xa1ed
        at sockaddr_in.sin_addr, dd 0 ; localhost
        at sockaddr_in.sin_zero, dd 0, 0
    iend
    sockaddr_in_len     equ $ - pop_sa

section .bss
    html resb 512 ; TODO: change to actual file size
    sock_descr resb 2
    client_descr resb 2

section .text

_start:
    call _read_file
    call _init_socket
    call _listen

    .mainloop:
        call     _accept
        call     _return_html

        ;; Close client socket
        mov    rdi, [client_descr]
        call   _close_sock
        mov    word [client_descr], 0
    jmp    .mainloop

    call _exit

_read_file: ; reads file to html
    mov rax, 2 ; open syscall
    mov rdi, file_path
    xor rsi, rsi ; 0 - read only
    mov rdx, 0 ;
    syscall

    cmp rax, 0 ; check open error
    jle _file_read_err
    
    mov rdi, rax ; read file into memory
    xor rax, rax ; 0 - SYS_READ
    mov rsi, html
    mov rdx, 512 ; TODO: change to actual file size
    syscall

    cmp rax, 0 ; check read error TODO: do we need it?
    jle _file_read_err
 
    mov rax, 3 ; close file, rdi already contains file descriptor
    syscall

    ret

_print:
    mov rax, 1  ; write syscall
    mov rdi, 1  ; to stdout
    syscall

_exit:
    mov rax, 60
    xor rdi, rdi ; put 0 code to rbi - all OK
    syscall

_file_read_err:
    mov rsi, file_read_err_msg ; print params
    mov rdx, file_read_err_msg_len
    call _print
    call _exit

_socket_err:
    mov rsi, socket_err_msg ; print params
    mov rdx, socket_err_msg
    call _print
    call _exit

_return_html:
    mov     rax, 1               ; SYS_WRITE
    mov     rdi, [client_descr]        ; client socket fd
    mov     rsi, html         ; buffer
    mov     rdx, 512    ; number of bytes received in _read
    syscall

    ret

;; Performs a sys_socket call to initialise a TCP/IP listening socket, storing 
;; socket file descriptor in the sock variable
_init_socket:
    mov rax, 41     ; SYS_SOCKET
    mov rdi, 2      ; AF_INET
    mov rsi, 1      ; SOCK_STREAM
    mov rdx, 0
    syscall

    ;; Check socket was created correctly
    cmp rax, 0
    jle _socket_err

    ;; Store socket descriptor in variable
    mov [sock_descr], rax

    ret

;; Calls sys_bind and sys_listen to start listening for connections
_listen:
    mov        rax, 49                  ; SYS_BIND
    mov        rdi, [sock_descr]        ; listening socket fd
    mov        rsi, pop_sa              ; sockaddr_in struct
    mov        rdx, sockaddr_in_len     ; length of sockaddr_in
    syscall

    ;; Check call succeeded
    cmp        rax, 0
    jl         _socket_err

    ;; Bind succeeded, call sys_listen
    mov        rax, 50          ; SYS_LISTEN
    mov        rsi, 1           ; backlog (dummy value really)
    syscall

    ;; Check for success
    cmp        rax, 0
    jl         _socket_err

    ret

;; Accepts a connection from a client, storing the client socket file descriptor
;; in the client variable and logging the connection to stdout
_accept:
    ;; Call sys_accept
    mov       rax, 43         ; SYS_ACCEPT
    mov       rdi, [sock_descr]     ; listening socket fd
    mov       rsi, 0          ; NULL sockaddr_in value as we don't need that data
    mov       rdx, 0          ; NULLs have length 0
    syscall

    ;; Check call succeeded
    cmp       rax, 0
    jl        _socket_err

    ;; Store returned fd in variable
    mov     [client_descr], rax

    ret

;; Performs sys_close on the socket in rdi
_close_sock:
    mov     rax, 3        ; SYS_CLOSE
    syscall

    ret