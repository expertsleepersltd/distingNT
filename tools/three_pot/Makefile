
outputs := $(patsubst %.spn,%.3pot,$(wildcard *.spn))
texts := $(patsubst %.spn,%.text,$(wildcard *.spn))
objects := $(patsubst %.spn,%.o,$(wildcard *.spn))
cpps := $(patsubst %.spn,%.cpp,$(wildcard *.spn))
hexs := $(patsubst %.spn,%.hex,$(wildcard *.spn))

all: $(outputs)

clean:
	rm -f $(outputs) $(cpps) $(objects) $(texts) $(hexs)

%.cpp: %.spn
	python3 spn_to_c.py $^ > $@

%.o: %.cpp
	arm-none-eabi-c++ -mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -g -Os -fPIC -Wall -I. -c -o $@ $^

%.text: %.o
	arm-none-eabi-objcopy --only-section .text $^ $@

%.hex: %.text
	arm-none-eabi-objcopy -O ihex $^ $@

%.3pot: %.hex
	python3 make_3pot.py $^ > $@
