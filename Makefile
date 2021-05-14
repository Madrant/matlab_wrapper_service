# Project directories
OBJ_DIR := obj
OUT_DIR := out

MATLAB_SRC=Matlab
GEN_SRC=CodeGen
WRAPPER_SRC=wrapper

# There must be only one project in $(GEN_SRC) with defines.txt inside
PROJECT=$(shell basename $(shell find $(GEN_SRC) -type f -name defines.txt -printf "%h\n"))

# Output file
TARGET = model

# Compiler setup
CC = g++
NVCC = nvcc

# C Build parameters
C_DEF += -DDEBUG
C_WARN += -Wall -Wextra -Wconversion -Wsign-conversion -Weffc++ -Wno-unused-function
C_PARAMS += -Ofast -fpic -fpermissive

# CUDA compiler parametersr
CUDA_PARAMS += -Xcompiler -fPIC

# Linker parameters
L_PARAMS += -flto
L_PARAMS += -Wl,--gc-sections

LIBS += -lm -ldl

L_CUDA_PARAMS += -L$(CUDA_PATH)/lib64
CUDA_LIBS += -lcuda -lcublas -lcusolver -lcudart

# Modify PATH to setup Nvidia CUDA binaries path
CUDA_PATH ?= /usr/local/cuda-11.2

export PATH := $(CUDA_PATH)/bin:$(PATH)

# Check additional component directory CodeGen/slprj for presence
ifneq ("$(wildcard $(GEN_SRC)/slprj)", "")
SLPRJ = $(GEN_SRC)/slprj
endif

# Files to compile
#
# C
C_FILES += $(wildcard $(GEN_SRC)/$(PROJECT)/*.c)
C_FILES += $(wildcard wrapper/*.c)
C_FILES += $(shell find $(MATLAB_SRC) -type f -name *.c -print)

ifdef SLPRJ
C_FILES += $(shell find $(SLPRJ) -type f -name *.c -print)
endif

# CPP
CPP_FILES += $(wildcard $(GEN_SRC)/$(PROJECT)/*.cpp)
CPP_FILES += $(wildcard wrapper/*.cpp)
CPP_FILES += $(shell find $(MATLAB_SRC) -type f -name *.cpp -print)

ifdef SLPRJ
CPP_FILES += $(shell find $(SLPRJ) -type f -name *.cpp -print)
endif

# CUDA
CU_FILES += $(wildcard $(GEN_SRC)/$(PROJECT)/*.cu)

# Associate .c files with .o files by name
#
# C
C_DIRS += $(GEN_SRC)/$(PROJECT)
C_DIRS += $(shell find $(MATLAB_SRC) -type f -name *.c -printf "%h\n" | uniq)
C_DIRS += $(shell find $(SLPRJ) -type f -name *.c -printf "%h\n" | uniq)
C_DIRS += $(WRAPPER_SRC)

vpath %.c $(C_DIRS)

# CPP
CPP_DIRS += $(GEN_SRC)/$(PROJECT)
CPP_DIRS += $(shell find $(SLPRJ) -type f -name *.cpp -printf "%h\n" | uniq)
CPP_DIRS += $(shell find $(MATLAB_SRC) -type f -name *.cpp -printf "%h\n" | uniq)
CPP_DIRS += $(WRAPPER_SRC)

vpath %.cpp $(CPP_DIRS)

# CUDA
vpath %.cu $(GEN_SRC)/$(PROJECT)

# Place all object files to $(OBJ_DIR) during build
C_O_FILES := $(addprefix $(OBJ_DIR)/, $(patsubst %.c, %.c.o, $(notdir $(C_FILES))))
CPP_O_FILES := $(addprefix $(OBJ_DIR)/, $(patsubst %.cpp, %.cpp.o, $(notdir $(CPP_FILES))))
CU_O_FILES :=  $(addprefix $(OBJ_DIR)/, $(patsubst %.cu, %.cu.o, $(notdir $(CU_FILES))))

O_FILES := $(C_O_FILES) $(CPP_O_FILES) $(CU_O_FILES)

# Include path
H_DIRS = $(shell find $(MATLAB_SRC) -type f -name *.h -printf "%h\n" | uniq)
HPP_DIRS = $(shell find $(MATLAB_SRC) -type f -name *.hpp -printf "%h\n" | uniq)

ifdef SLPRJ
H_DIRS += $(shell find $(SLPRJ) -type f -name *.h -printf "%h\n" | uniq)
HPP_DIRS += $(shell find $(SLPRJ) -type f -name *.hpp -printf "%h\n" | uniq)
endif

INCLUDE_PATH += -I$(GEN_SRC)/$(PROJECT)
INCLUDE_PATH += -I$(WRAPPER_SRC)
INCLUDE_PATH += $(addprefix -I,$(H_DIRS))
INCLUDE_PATH += $(addprefix -I,$(HPP_DIRS))

# Setup CUDA include path if .cu files is found
ifneq ($(CU_O_FILES),)
INCLUDE_PATH += -I$(CUDA_PATH)/include
endif

# Matlab build definitions (from defines.txt)
M_DEF_CONTENT=$(shell cat $(GEN_SRC)/$(PROJECT)/defines.txt)
M_DEF = $(addprefix -D,$(M_DEF_CONTENT))

# Setup CUDA linker parameters if .cu files is found
ifneq ($(CU_O_FILES),)
L_PARAMS += $(L_CUDA_PARAMS)
LIBS += $(CUDA_LIBS)
endif

.PHONY: all
all: show static dynamic app list

.PHONY: prepare
prepare:
	mkdir -p $(OBJ_DIR)
	mkdir -p $(OUT_DIR)

.PHONY: list
list:
	ls -lh $(OUT_DIR)

.PHONY: show
show:
	@echo "Project: $(PROJECT)"
	@echo "C object files:"
	@echo "$(C_O_FILES)"
	@echo "CPP object files:"
	@echo "$(CPP_O_FILES)"
	@echo "CUDA object files:"
	@echo "$(CU_O_FILES)"

obj/%.c.o: %.c
	@echo "# $< : $@"
	$(CC) $(C_PARAMS) $(C_WARN) $(C_DEF) $(M_DEF) $(INCLUDE_PATH) -c -o $@ $<

obj/%.cpp.o: %.cpp
	@echo "# $< : $@"
	$(CC) $(C_PARAMS) $(C_WARN) $(C_DEF) $(M_DEF) $(INCLUDE_PATH) -c -o $@ $<

obj/%.cu.o: %.cu
	@echo "# $< : $@"
	$(NVCC) $(CUDA_PARAMS) $(C_DEF) $(M_DEF) $(INCLUDE_PATH) -c -o $@ $<

.PHONY: app
app: prepare $(O_FILES)
# Link object files
	@echo "# Linking $(TARGET)"
	$(CC) -o $(OUT_DIR)/$(TARGET) $(L_PARAMS) $(LIBS) $(O_FILES)

.PHONY: static
static: prepare $(O_FILES)
# Link object files
	@echo "# Linking lib$(TARGET).a"
	ar rcs $(OUT_DIR)/lib$(TARGET).a $(O_FILES)

# Show sections size
	@echo "# Information for $(TARGET).a"
	size $(OUT_DIR)/lib$(TARGET).a

.PHONY: dynamic
dynamic: prepare $(O_FILES)
# Link object files
	@echo "# Linking lib$(TARGET).so"
	$(CC) -shared -o $(OUT_DIR)/lib$(TARGET).so $(L_PARAMS) $(LIBS) $(O_FILES)

.PHONY: clean
clean:
	@echo "Cleaning generated files"
	rm -f $(OBJ_DIR)/*.o
	rm -f $(OUT_DIR)/lib$(TARGET).a
	rm -f $(OUT_DIR)/lib$(TARGET).so
	rm -f $(OUT_DIR)/*.sym
	rm -f $(OUT_DIR)/*.S
