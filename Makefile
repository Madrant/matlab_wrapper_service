# Project directories
OBJ_DIR := obj
OUT_DIR := out

PROJECT = model_name

# Files to compile
C_FILES += $(wildcard CodeGen/$(PROJECT)/*.c)
C_FILES += $(wildcard Matlab/rtw/c/src/*.c)
C_FILES += $(wildcard Matlab/rtw/c/src/common/*.c)
C_FILES += $(wildcard wrapper/*.c)

# Associate .c files with .o files by name
vpath %.c CodeGen/$(PROJECT)
vpath %.c Matlab/rtw/c/src
vpath %.c Matlab/rtw/c/src/common
vpath %.c wrapper

# Place all object files to $(OBJ_DIR) during build
O_FILES := $(addprefix $(OBJ_DIR)/, $(patsubst %.c, %.o, $(notdir $(C_FILES))))

# Output file
TARGET = model

# Compiler setup
CC = g++

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

# Matlab build definitions (from defines.txt)
M_STD_DEF += -DMODEL=model -DNUMST=2 -DNCSTATES=0 -DHAVESTUDIO -DRT -DUSE_RTMODEL
M_DEF += -DCLASSIC_INTERFACE=0 -DALLOCATIONFCN=0 -DTID01EQ=0 -DMAT_FILE=0 -DONESTEPFCN=1 -DTERMFCN=1 -DMULTI_INSTANCE_CODE=0 -DINTERGER_CODE=0 -DMT=0

# C Build parameters
C_DEF += -DDEBUG
C_WARN += -Wall -Wextra -Wconversion -Wsign-conversion -Weffc++ -Wno-unused-function
C_PARAMS += -Ofast -fpic

# Linker parameters
L_PARAMS += -flto
L_PARAMS += -Wl,--gc-sections
LIBS += -lm

.PHONY: all
all: static dynamic list

.PHONY: prepare
prepare:
	mkdir -p $(OBJ_DIR)
	mkdir -p $(OUT_DIR)

.PHONY: list
list:
	ls -lh $(OUT_DIR)

obj/%.o: %.c
	@echo "# $< : $@"
	$(CC) $(C_PARAMS) $(C_WARN) $(C_DEF) $(M_STD_DEF) $(M_DEF) $(INCLUDE_PATH) -c -o $@ $<

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
	$(CC) -shared -o $(OUT_DIR)/lib$(TARGET).so $(O_FILES)

.PHONY: clean
clean:
	@echo "Cleaning generated files"
	rm -f $(OBJ_DIR)/*.o
	rm -f $(OUT_DIR)/lib$(TARGET).a
	rm -f $(OUT_DIR)/lib$(TARGET).so
	rm -f $(OUT_DIR)/*.sym
	rm -f $(OUT_DIR)/*.S
