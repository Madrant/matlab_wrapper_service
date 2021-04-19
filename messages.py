#!/usr/bin/python3

from ctypes import *

import struct
import math

class printable_ctypes_struct(Structure):
    # display structure content using print()
    def __str__(self):
        str = ""

        for field in self._fields_:
            str += (
                "%s: %s " %
                (field[0], getattr(self, field[0]))
            )

        return str

class packed_ctypes_message():
    # Convert ctypes defined message to bytes
    def to_bytes(self, debug = False):
        # Create tuple from ctypes fields
        m_tuple = tuple(
            (getattr(self, field[0])) for field in self._fields_
        )

        if debug: print(m_tuple)

        # Convert message to bytes using struct.pack
        m_bytes = struct.pack(self.format, *m_tuple)

        if debug: print(m_bytes.hex())

        return m_bytes

    @classmethod
    def from_bytes(class_name, m_bytes):
        return class_name(*struct.unpack(class_name.format, m_bytes))

    def round_float(self, precision = 4, debug = False):
        for field in self._fields_:
            val = getattr(self, field[0])

            if not isinstance(val, float): continue

            rounded_val = round(val, precision)
            setattr(self, field[0], rounded_val)

            if debug:
                val2 = getattr(self, field[0])
                print("{}: {} -> {}".format(field[0], val, val2))

    def normalize_float(self, norm = 10000, debug = False):
        for field in self._fields_:
            val = getattr(self, field[0])

            if not isinstance(val, float): continue

            rounded_val = math.modf(val * norm)[1]
            setattr(self, field[0], rounded_val)

            if debug:
                val2 = getattr(self, field[0])
                print("{}: {} -> {}".format(field[0], val, val2))

class network_message(printable_ctypes_struct, packed_ctypes_message): pass

# Transport header
class tr_header(network_message):
    _fields_ = [
        ("type",        c_uint32),
        ("num",         c_uint32),
        ("sec",         c_uint32),
        ("usec",        c_uint32)
    ]

    format = "!IIII"
    size = struct.calcsize(format)

# Input message
class input_message(network_message):
    name = "Input message"
    tr_type = 1

    tr_header = tr_header()

    _fields_ = [
        ("a",               c_float),
        ("b",               c_float),
        ("c",               c_float),
        ("d",               c_float)
    ]

    format = "!ffff"
    size = struct.calcsize(format)

# Output message
class output_message(network_message):
    name = "Output message"
    tr_type = 2

    _fields_ = [
        ("x",             c_float),
        ("y",             c_float),
        ("z",             c_float)
    ]

    format = "!fff"
    size = struct.calcsize(format)

# Transport message
class tr_message():

    max_size = 4096

    def __init__(self, data):
        # Parse transport header
        try:
            self.tr_header = tr_header(*struct.unpack(
                tr_header.format,
                data[0:tr_header.size])
            )
        except struct.error as e:
            print("Cannot unpack transport header: %s" % str(e))
            raise

        # Calculate body size
        body_size = len(data) - tr_header.size

        if body_size <= 0:
            self.body = b''
            print("Empty transport message")
            return

        # Save message body
        self.body = data[tr_header.size:tr_header.size + body_size]

    def convert(self, message):
        try:
            unpacked_message = message(
                *struct.unpack(message.format, self.body[0:message.size])
            )
        except struct.error as e:
            print(
                "tr_message: convert(): Failed to convert %u bytes to '%s': %s" %
                (len(self.body), message.__qualname__, str(e))
            )
            raise

        unpacked_message.tr_header = self.tr_header

        return unpacked_message
