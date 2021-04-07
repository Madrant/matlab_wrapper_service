// Model output
struct input_data_t
{
    float a;
    float b;
    float c;
    float d;
};

typedef struct input_data_t input_data;

// Model input
struct output_data_t
{
    float x;
    float y;
    float z;
};

typedef struct output_data_t output_data;

// Model wrapper functions
void model_init();

void model_step(input_data* input, output_data* output);

void model_terminate();
