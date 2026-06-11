# libutil — portable C11 utility library
#
# Targets:
#   make            build the static library (build/libutil.a)
#   make test       build and run the unit tests
#   make clean      remove build artifacts
#
# Override the compiler/flags from the environment, e.g.
#   make CC=clang
#   make CFLAGS_EXTRA="-fsanitize=address,undefined"

CC      ?= cc
AR      ?= ar
CSTD    ?= -std=c11
WARN     = -Wall -Wextra -Wpedantic -Werror
CFLAGS   = $(CSTD) $(WARN) -O2 -Iinclude $(CFLAGS_EXTRA)

BUILD    = build
LIB      = $(BUILD)/libutil.a

SRCS     = $(wildcard src/*.c)
OBJS     = $(patsubst src/%.c,$(BUILD)/%.o,$(SRCS))

TEST_SRCS = $(wildcard tests/test_*.c)
TEST_BINS = $(patsubst tests/%.c,$(BUILD)/%,$(TEST_SRCS))

.PHONY: all test clean

all: $(LIB)

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.o: src/%.c | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(LIB): $(OBJS)
	$(AR) rcs $@ $(OBJS)

# Each test binary links against the static library.
$(BUILD)/%: tests/%.c $(LIB) | $(BUILD)
	$(CC) $(CFLAGS) -Itests $< $(LIB) -o $@

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
