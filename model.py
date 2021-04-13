import pathlib
import datetime
import dbm
import hashlib
import copy
import threading

from messages import input_message, output_message
from ctypes import CDLL, POINTER, byref

class model:
    # Open model library
    def __init__(self, lib, db_path = "db", cache_enabled = False):
        libname = pathlib.Path().absolute() / lib
        print("Loading library: %s" % libname)

        self.c_lib = CDLL(libname)

        self.cache_enabled = cache_enabled
        self.db_path = db_path

        self.mutex = threading.Lock()

    # Initialize
    def init(self):
        print("Call init()")
        self.c_lib.model_init()

        # Setup model input
        print("Setup model input")
        self.model_step = self.c_lib.model_step
        self.model_step.argtypes = [
            POINTER(input_message),
            POINTER(output_message)
        ]

        if self.cache_enabled:
            self.db = dbm.open(self.db_path, 'c')

    def step(self, input_data, debug = False):
        # Generate MD5 key
        if self.cache_enabled:
            input_bytes = input_data.to_bytes()
            input_md5 = hashlib.md5(input_bytes).hexdigest()

            if debug:
                print("Key: %s" % (input_md5))
                print(input_data)

        # Prepare model output
        output_data = output_message()

        from_cache = False
        start_usec = datetime.datetime.now()

        # Try to get model output from cache
        if self.cache_enabled and input_md5 in self.db:
            m_bytes = self.db[input_md5]
            output_data = output_message.from_bytes(m_bytes)

            from_cache = True
        else:
            # Execute model step
            self.model_step(
                byref(input_data),
                byref(output_data)
            )

            from_cache = False

            # Cache model output
            if self.cache_enabled:
                self.mutex.acquire()

                output_bytes = output_data.to_bytes()
                self.db[input_md5] = output_bytes

                self.mutex.release()

        # Calculate execution time
        stop_usec = datetime.datetime.now();
        step_time = stop_usec - start_usec;

        return (output_data, from_cache, step_time)

    def terminate(self):
        print("Call terminate()")
        self.c_lib.model_terminate()

        if self.cache_enabled:
            self.db.close()
