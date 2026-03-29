EVENTS := $(sort $(wildcard 20*-*-*-*/))

.PHONY: all clean $(EVENTS)

all: $(EVENTS)

$(EVENTS):
	$(MAKE) -C $@

clean:
	@for dir in $(EVENTS); do $(MAKE) -C $$dir clean; done
