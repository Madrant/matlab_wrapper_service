# Project directories
OBJ_DIR := obj
OUT_DIR := out

PROJECT = model_name

# Files to compile
C_FILES += $(wildcard CodeGen/$(PROJECT)/*.c)
C_FILES += $(wildcard Matlab/rtw/c/src/*.c)
C_FILES += $(wildcard Matlab/rtw/c/src/common/*.c)
C_FILES += $(wildcard wrapper/*.c)

CPP_FILES += $(wildcard CodeGen/$(PROJECT)/*.cpp)
CPP_FILES += $(wildcard Matlab/rtw/c/src/*.cpp)
CPP_FILES += $(wildcard Matlab/rtw/c/src/common/*.cpp)
CPP_FILES += $(wildcard wrapper/*.cpp)

CU_FILES += $(wildcard CodeGen/$(PROJECT)/*.cu)

# Associate .c files with .o files by name
vpath %.c CodeGen/$(PROJECT)
vpath %.c Matlab/rtw/c/src
vpath %.c Matlab/rtw/c/src/common
vpath %.c wrapper

vpath %.cpp CodeGen/$(PROJECT)
vpath %.cpp Matlab/rtw/c/src
vpath %.cpp Matlab/rtw/c/src/common
vpath %.cpp wrapper

vpath %.cu CodeGen/$(PROJECT)

# Place all object files to $(OBJ_DIR) during build
C_O_FILES := $(addprefix $(OBJ_DIR)/, $(patsubst %.c, %.c.o, $(notdir $(C_FILES))))
CPP_O_FILES := $(addprefix $(OBJ_DIR)/, $(patsubst %.cpp, %.cpp.o, $(notdir $(CPP_FILES))))
CU_O_FILES :=  $(addprefix $(OBJ_DIR)/, $(patsubst %.cu, %.cu.o, $(notdir $(CU_FILES))))

O_FILES := $(C_O_FILES) $(CPP_O_FILES) $(CU_O_FILES)

# Output file
TARGET = model

# Compiler setup
CC = g++
NVCC = nvcc

# Modify PATH to setup Nvidia CUDA binaries path
CUDA_PATH ?= /usr/local/cuda-11.2

export PATH := $(CUDA_PATH)/bin:$(PATH)

# Include path
MATLAB_SRC=Matlab
GEN_SRC=CodeGen
WRAPPER_SRC=wrapper

INCLUDE_PATH += -I$(GEN_SRC)/$(PROJECT)
INCLUDE_PATH += -I$(MATLAB_SRC)/extern/include
INCLUDE_PATH += -I$(MATLAB_SRC)/simulink/include
INCLUDE_PATH += -I$(MATLAB_SRC)/toolbox/shared/dsp/vision/matlab/include
INCLUDE_PATH += -I$(MATLAB_SRC)/rtw/c/src
INCLUDE_PATH += -I$(MATLAB_SRC)/rtw/c/src/ext_mode/common
INCLUDE_PATH += -I$(WRAPPER_SRC)

# Setup CUDA include path if .cu files is found
ifneq ($(CU_O_FILES),)
INCLUDE_PATH += -I$(CUDA_PATH)/include
endif

# Matlab build definitions (from defines.txt)
M_STD_DEF += -DMODEL=MODEL -DNUMST=2 -DNCSTATES=0 -DHAVESTUDIO -DRT -DUSE_RTMODEL
M_DEF += -DCLASSIC_INTERFACE=0 -DALLOCATIONFCN=0 -DTID01EQ=0 -DMAT_FILE=0 -DONESTEPFCN=1 -DTERMFCN=1 -DMULTI_INSTANCE_CODE=0 -DINTERGER_CODE=0 -DMT=0

# C Build parameters
C_DEF += -DDEBUG
C_WARN += -Wall -Wextra -Wconversion -Wsign-conversion -Weffc++ -Wno-unused-function
C_PARAMS += -Ofast -fpic

# CUDA compiler parametersr
CUDA_PARAMS += -Xcompiler -fPIC

# Linker parameters
L_PARAMS += -flto
L_PARAMS += -Wl,--gc-sections

LIBS += -lm

L_CUDA_PARAMS += -L$(CUDA_PATH)/lib64
CUDA_LIBS += -lcuda -lcublas -lcusolver -lcudart

# Setup CUDA linker parameters if .cu files is found
ifneq ($(CU_O_FILES),)
L_PARAMS += $(L_CUDA_PARAMS)
LIBS += $(CUDA_LIBS)
endif

.PHONY: all
all: show static dynamic list

.PHONY: prepare
prepare:
	mkdir -p $(OBJ_DIR)
	mkdir -p $(OUT_DIR)

.PHONY: list
list:
	ls -lh $(OUT_DIR)

.PHONY: show
show:
	@echo "C object files:"
	@echo "$(O_FILES)"
	@echo "CPP object files:"
	@echo "$(CPP_O_FILES)"
	@echo "CUDA object files:"
	@echo "$(CU_O_FILES)"

obj/%.c.o: %.c
	@echo "# $< : $@"
	$(CC) $(C_PARAMS) $(C_WARN) $(C_DEF) $(M_STD_DEF) $(M_DEF) $(INCLUDE_PATH) -c -o $@ $<

obj/%.cpp.o: %.cpp
	@echo "# $< : $@"
	$(CC) $(C_PARAMS) $(C_WARN) $(C_DEF) $(M_STD_DEF) $(M_DEF) $(INCLUDE_PATH) -c -o $@ $<

obj/%.cu.o: %.cu
	@echo "# $< : $@"
	$(NVCC) $(CUDA_PARAMS) $(C_DEF) $(M_STD_DEF) $(M_DEF) $(INCLUDE_PATH) -c -o $@ $<

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
