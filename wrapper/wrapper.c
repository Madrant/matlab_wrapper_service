#ifdef __cplusplus
extern "C" {
#endif

#include "wrapper.h"

#include <stdio.h>

#include "rtwtypes.h"
#include "MODEL.h"

#ifndef MODEL
# error Must specify a model name.  Define MODEL=name.
#else
/* create generic macros that work with any model */
# define EXPAND_CONCAT(name1,name2) name1 ## name2
# define CONCAT(name1,name2) EXPAND_CONCAT(name1,name2)
# define MODEL_INITIALIZE CONCAT(MODEL,_initialize)
# define MODEL_STEP       CONCAT(MODEL,_step)
# define MODEL_TERMINATE  CONCAT(MODEL,_terminate)
# define RT_MDL           CONCAT(MODEL,_M)
#endif

#if 1
#define WRAPPER_DEBUG
#endif

#ifdef WRAPPER_DEBUG
#define info(format, ...) printf("Info: " format, ##__VA_ARGS__)
#else
#define info(format, ...) ((void)(0))
#endif

#define error(format, ...) printf("Error: " format, ##__VA_ARGS__)

void model_init()
{
    printf(__PRETTY_FUNCTION__);

    MODEL_INITIALIZE();
}

void model_step(input_data* input, output_data* output)
{
    const char_T *errStatus = (const char_T *) (rtmGetErrorStatus(RT_MDL));
    if (rtmGetErrorStatus(RT_MDL) != NULL)
    {
        error("%s\n", errStatus);
        return;
    }

    /* Initialize model inputs here */
    info(
        "a: %.2f b: %.2f c: %.2f d: %.2f\r\n",
        input->a, input->b, input->c, input->d
    );

    /* Process one model step */
    MODEL_STEP();

    /* Read model outputs here */
    info(
        "x: %.2f y: %.2f z: %.2f\r\n",
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
