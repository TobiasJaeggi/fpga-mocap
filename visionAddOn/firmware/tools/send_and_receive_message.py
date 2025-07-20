import socket
# configure your device to be on the same subnet, example:
# ip: 10.0.0.2, netmask: 255.255.255.0, gateway: 0.0.0.0

IP = '10.0.0.1'
PORT = 80

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect((IP, PORT))
try:
    sock.send(bytes("hello", encoding='utf-8'))
    while True:
        data = sock.recv(1024)
        if not data:
            break
        print(data.decode('utf-8'))
        break
finally:
    sock.close()