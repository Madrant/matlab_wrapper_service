#!/usr/bin/python3

import datetime

from model import model
from messages import input_message, output_message

if __name__ == "__main__":
    # Parameters
    cache_enabled = False
    model_debug = False

    steps = 1
    step_output = True

    # Initialize model
    model = model("out/libmodel.so", db_path = "db_test", cache_enabled = cache_enabled)
    model.init()

    # Setup model input
    input_data = input_message()

    print("Input:")
    print(input_data)

    # Prepare model output
    output_data = output_message()

    # Measure time
    start_usec = datetime.datetime.now()

    # Call model
    for step in range(steps):
        # Execute model step
        (output_data, from_cache, step_time) = model.step(input_data, debug = model_debug)

        if step_output:
            # Print step execution time
            print(
                "Model step: %s Time: %u sec %u usec" %
                ("Cached" if from_cache else "Non-cached",
                step_time.seconds, step_time.microseconds)
            )

            # Print model output
            print("Output: %s" % ("Cached" if from_cache else "Non-cached"))
            print(output_data)

    stop_usec = datetime.datetime.now()
    model_time = stop_usec - start_usec

    # Terminate
    model.terminate()

    print("Model: %u steps executed for %u sec %u usec" % (steps, model_time.seconds, model_time.microseconds))
