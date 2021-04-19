import socket
import threading
import struct
import sys
import datetime

from collections import deque
from messages import *

class udp_listener(threading.Thread):
    def __init__(self, ip, port, message, maxlen = 20, cached_message_lifetime_sec = 60):
        super().__init__()

        self.stack = deque(maxlen = maxlen)

        self.mutex = threading.Lock()
        self.is_running = False

        self.ip = ip
        self.port = port

        self.message_type = message
        self.last_message = message()

        self.last_message_time = datetime.datetime.now()
        self.last_message_lifetime_sec = cached_message_lifetime_sec

        self.message_received = False

        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        print("Listen on %s: %u" % (ip, port))
        self.sock.bind((ip, port))

    def run(self):
        self.is_running = True

        while self.is_running:
            # TypeError is throwed on socket.shutdown()
            try:
                data, (ip, port) = self.sock.recvfrom(tr_message.max_size)
            except TypeError as e:
                #print("Socket shutdown")
                return

            #print("Packet: IP: %s Port: %u Size: %u Data: %s" % (ip, port, len(data), data.hex()))

            # Try to convert packet to transport message
            try:
                tr = tr_message(data)
            except struct.error as e:
                print("Can not unpack transport message: %s" % str(e))
                continue

            # Transport message received here
            print("TR message:")
            print(tr.tr_header)

            if tr.tr_header.type != self.message_type.tr_type:
                print(
                    "%s: Type mismatch: %u Must be: %u" %
                    (self.message_type.name, tr.tr_header.type, self.message_type.tr_type)
                )
                print(tr.tr_header)

                continue

            # Convert transport message to concrete message
            try:
                received_message = tr.convert(self.message_type)
            except struct.error as e:
                print("Failed to convert %u bytes to '%s': %s" % (len(data), self.message_type.__qualname__, str(e)))
                continue

            self.mutex.acquire()

            self.last_message = received_message
            self.last_message_time = datetime.datetime.now()

            self.stack.append(received_message)
            self.message_received = True

            self.mutex.release()

    def join(self):
        try:
            self.is_running = False
            self.sock.shutdown(socket.SHUT_RDWR)
            self.sock.close()
        except OSError as e:
            pass

    def is_message_received(self):
        return self.message_received

    def is_cached_message_out_of_date(self):
        cached_message_age_sec = (datetime.datetime.now() - self.last_message_time).total_seconds()

        message_out_of_date = False
        if cached_message_age_sec > self.last_message_lifetime_sec:
             message_out_of_date = True

        return message_out_of_date

    def first(self):
        while not len(self.stack):
            pass

        self.mutex.acquire()
        m = self.stack.popleft()
        self.mutex.release()

        return m

    def last(self, cached = False):
        # If queue is empty but message is received at least once
        if cached and self.is_message_received() and len(self.stack) == 0:
            if not self.is_cached_message_out_of_date():
                return self.last_message

        # Wait for a new message
        while not len(self.stack):
            pass

        self.mutex.acquire()
        m = self.stack.pop()
        self.mutex.release()

        return m

    def size(self):
        return len(self.stack)
