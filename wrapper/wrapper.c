#include "rtmodel.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "wrapper.h"

#include <stdio.h>

#include "rtwtypes.h"

#ifndef MODEL
# error Must specify a model name.  Define MODEL=name.
#endif

#define EXPAND_CONCAT(name1,name2) name1 ## name2
#define CONCAT(name1,name2) EXPAND_CONCAT(name1,name2)

// If model is C++
#ifdef MODEL_CLASSNAME
# define MODEL_INSTANCE   CONCAT(MODEL,_Obj)
# define MODEL_INITIALIZE MODEL_INSTANCE.initialize
# define MODEL_STEP       MODEL_INSTANCE.MODEL_STEPNAME
# define MODEL_TERMINATE  MODEL_INSTANCE.terminate
static MODEL_CLASSNAME MODEL_INSTANCE;
#endif

// If model is C
#ifndef MODEL_CLASSNAME
# define MODEL_INITIALIZE CONCAT(MODEL,_initialize)
# define MODEL_STEP       CONCAT(MODEL,_step)
# define MODEL_TERMINATE  CONCAT(MODEL,_terminate)
# define RT_MDL           CONCAT(MODEL,_M)
#endif

#if 0
#define WRAPPER_DEBUG
#endif

#ifdef WRAPPER_DEBUG
# define info(format, ...) printf("Info: " format, ##__VA_ARGS__)
#else
# define info(format, ...) ((void)(0))
#endif

#define error(format, ...) printf("Error: " format, ##__VA_ARGS__)

void model_init()
{
    printf(__PRETTY_FUNCTION__);

    MODEL_INITIALIZE();
}

// Define macros to set model input and get model output
#ifdef MODEL_CLASSNAME // C++ generated model
# define MODEL_SET_INPUT(input)  MODEL_INSTANCE.setExternalInputs(&input)
# define MODEL_GET_OUTPUT(input) MODEL_INSTANCE.getExternalOutputs()
#else // C generated model
// Please check model input and output variables names
# define MODEL_SET_INPUT(input)  MODEL_U = input
# define MODEL_GET_OUTPUT(input) MODEL_Y
#endif

void model_step(input_data* input, output_data* output)
{
    /* Initialize model inputs here */

    info(
        "Input: a: %.2f b: %.2f c: %.2f d: %.2f\r\n",
        input->a, input->b, input->c, input->d
    );

    MODEL_SET_INPUT(input);

    /* Process one model step */
    MODEL_STEP();

    /* Read model outputs here */
    // ExtY_MODEL_T output = MODEL_GET_OUTPUT();

    info(
        "Output: x: %.2f y: %.2f z: %.2f\r\n",
        output->x, output->y, output->z
    );
}

void model_terminate()
{
    printf(__PRETTY_FUNCTION__);

    MODEL_TERMINATE();
}

#ifdef __cplusplus
} // extern C
#endif
