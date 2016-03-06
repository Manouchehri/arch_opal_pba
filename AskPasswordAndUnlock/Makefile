EXE = linuxpba
CXX = g++
CC = gcc
BUILD_DIR = /tmp/
CFLAGS += -O2 -I../sedutil/Common -I../sedutil/linux -I$(BUILD_DIR)
CXXFLAGS += -std=c++11 $(CFLAGS)

# File names
CXX_SOURCES := $(wildcard *.cpp)
CXX_SOURCES += $(abspath $(wildcard ../sedutil/Common/D*.cpp))
CXX_SOURCES += $(abspath $(wildcard ../sedutil/linux/*.cpp))
C_SOURCES := $(abspath $(wildcard ../sedutil/Common/pbkdf2/*.c))
OBJECTS =  $(addprefix $(BUILD_DIR)/,$(CXX_SOURCES:.cpp=.o))
OBJECTS +=  $(addprefix $(BUILD_DIR)/,$(C_SOURCES:.c=.o))

#all:
#	echo $(OBJECTS)

all: $(BUILD_DIR)/$(EXE)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Main target
$(BUILD_DIR)/$(EXE): $(OBJECTS)
	$(CXX) $? -o $@

$(BUILD_DIR)/Version.h: $(BUILD_DIR)
	cd ../sedutil/linux && ./GitVersion.sh > $@

$(BUILD_DIR)/%.o: %.cpp $(BUILD_DIR)/Version.h
	mkdir -p $(dir $@)
	$(CXX) -c $(CXXFLAGS) $< -o $@

$(BUILD_DIR)/%.o: %.c $(BUILD_DIR)/Version.h
	mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS) $< -o $@
	
clean:
	rm -rf $(BUILD_DIR)

