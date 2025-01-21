# MIT License
# 
# Copyright (c) 2024 Expert Sleepers Ltd
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

inputs := $(wildcard spn/*.spn) $(wildcard spn/*/*.spn)
outputs := $(patsubst spn/%.spn,3pot/%.3pot,$(inputs))
texts := $(patsubst %.spn,%.text,$(inputs))
objects := $(patsubst %.spn,%.o,$(inputs))
cpps := $(patsubst %.spn,%.cpp,$(inputs))
hexs := $(patsubst %.spn,%.hex,$(inputs))

SPN_TO_C_PATH := ../../../spn_to_c

INCLUDE_PATH := $(SPN_TO_C_PATH)/include

all: $(outputs)

clean:
	rm -f $(outputs) $(cpps) $(objects) $(texts) $(hexs)

%.cpp: %.spn
	python3 $(SPN_TO_C_PATH)/spn_to_c.py $^ > $@

%.o: %.cpp
	arm-none-eabi-c++ -mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -g -Os -fPIC -Wall -I$(INCLUDE_PATH) -c -o $@ $^

%.text: %.o
	arm-none-eabi-objcopy --only-section .text $^ $@

%.hex: %.text
	arm-none-eabi-objcopy -O ihex $^ $@

3pot/%.3pot: spn/%.hex
	mkdir -p $(@D)
	python3 make_3pot.py $^ $(INCLUDE_PATH) > $@
