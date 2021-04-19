#!/usr/bin/python3

import socket
import struct
import threading
import sys
import pathlib
import math
import concurrent.futures

from ctypes import *
from messages import input_message, output_message
from model import model
from udp_listener import udp_listener

def process_input(model, input_data):
    (output_data, from_cache, step_time) = model.step(input_data, debug = False)

    return (output_data, from_cache, step_time)

def locate_model_library(lib_name):
    lib_path = "out/" + lib_name
    script_path = pathlib.Path(__file__).parent.absolute()

    # <script_path>/out/<lib_name>
    path = str(script_path) + lib_path
    if pathlib.Path(path).is_file():
        lib_path = path

    # <script_path>/<lib_name>
    path = str(script_path) + "/" + lib_name
    if pathlib.Path(path).is_file():
        lib_path = path

    # /usr/lib
    path = "/usr/lib/" + lib_name
    if pathlib.Path(path).is_file():
        lib_path = path

    # /usr/local/lib
    path = "/usr/local/lib/" + lib_name
    if pathlib.Path(path).is_file():
        lib_path = path

    return lib_path

if __name__ == "__main__":
    script_path = pathlib.Path(__file__).parent.absolute()

    # Search for model library
    lib_name = "libmodel.so"
    lib_path = locate_model_library(lib_name)

    # Initialize model
    db_path = str(script_path) + "/db"

    model = model(lib_path, db_path = db_path, cache_enabled = True)
    model.init()

    # Initialize network
    input_listener = udp_listener("0.0.0.0", 1234, input_message)
    input_listener.daemon = True
    input_listener.start()

    # Model output
    output_addr = ("192.168.253.100", 4321)
    output_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM);

    cache_counter = 0
    task_counter = 0

    cpu = 6

    # Main loop
    try:
        while True:
            # Calculate number of threads
            num_threads = min(input_listener.size(), cpu)
            num_threads = max(num_threads, 1)

            params = []

            # Prepare model inputs for concurrent execution
            for i in range(0, num_threads):
                params.append((
                    input_listener.first()
                ))

            # Display input data
            (input_data) = params[0]

            print(
                "Input: Num: %u Queue: %u" %
               (input_data.tr_header.num, input_listener.size())
            )
            print(input_data)

            # Execute model in 'num_threads' threads
            with concurrent.futures.ThreadPoolExecutor() as ex:
                futures = [ex.submit(process_input, model, param) for param in params]

            for future in futures:
                (output_data, from_cache, step_time) = future.result()

                task_counter += 1
                if from_cache: cache_counter += 1

                # Print execution time
                print(
                    "Model step: %s Time: %u sec %u usec" %
                    ("Cached" if from_cache else "Non-cached",
                    step_time.seconds, step_time.microseconds)
                )

                print("Output: Size: %u" % (output_data.size))
                print(output_data)

                # Send model output
                output_bytes = output_data.to_bytes()
                output_sock.sendto(output_bytes, output_addr)

            # Show statistics
            print("From cache: %u / %u: %.2f%%" % (cache_counter, task_counter, (cache_counter / task_counter) * 100))

    except KeyboardInterrupt:
        print("Keyboard interrupt")
        input_listener.join()
        sys.exit(0)
