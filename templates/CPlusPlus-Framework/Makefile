# appcore — C++17 framework/library
#
# Targets:
#   make            build the static library (build/libappcore.a)
#   make test       build and run the unit tests
#   make clean      remove build artifacts
#
# Override from the environment, e.g. `make CXX=clang++` or
# `make CXXFLAGS_EXTRA="-fsanitize=address,undefined"`.

CXX      ?= c++
AR       ?= ar
CXXSTD    = -std=c++17
WARN      = -Wall -Wextra -Wpedantic -Werror
CXXFLAGS  = $(CXXSTD) $(WARN) -O2 -Iinclude $(CXXFLAGS_EXTRA)
LDFLAGS   = -pthread

BUILD     = build
LIB       = $(BUILD)/libappcore.a

SRCS      = $(wildcard src/*.cpp)
OBJS      = $(patsubst src/%.cpp,$(BUILD)/%.o,$(SRCS))

TEST_SRCS = $(wildcard tests/test_*.cpp)
TEST_BINS = $(patsubst tests/%.cpp,$(BUILD)/%,$(TEST_SRCS))

.PHONY: all test clean

all: $(LIB)

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.o: src/%.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(LIB): $(OBJS)
	$(AR) rcs $@ $(OBJS)

$(BUILD)/%: tests/%.cpp $(LIB) | $(BUILD)
	$(CXX) $(CXXFLAGS) -Itests $< $(LIB) $(LDFLAGS) -o $@

test: $(TEST_BINS)
	@fail=0; \
	for t in $(TEST_BINS); do \
		echo "==> $$t"; \
		$$t || fail=1; \
		echo; \
	done; \
	exit $$fail

clean:
	rm -rf $(BUILD)
