import socket
# configure your device to be on the same subnet, example:
# ip: 10.0.0.2, netmask: 255.255.255.0, gateway: 0.0.0.0

OUTPUT_FILE = 'framebuffer'
PORT = 1055

server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
# Enable SO_REUSEADDR to allow immediate reuse after aborting
server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server_socket.bind(('0.0.0.0', PORT))

# Start listening for incoming connections
server_socket.listen(5)
print(f"Listening on port {PORT}...")

try:
    while True:
        # Accept an incoming connection
        client_socket, client_address = server_socket.accept()
        print(f"Connection from {client_address}")
        try:
            with open(OUTPUT_FILE, 'wb') as f: 
                while True:
                    data = client_socket.recv(1024)
                    if not data:
                        break
                    f.write(data)
                    #print("Received data:", data.decode(errors="ignore"))
        finally:
            client_socket.close()
            print("done")
finally:
        server_socket.close()