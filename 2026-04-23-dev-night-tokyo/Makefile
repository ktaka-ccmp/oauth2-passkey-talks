.DEFAULT_GOAL := all

ROOT := ..
SHARED := $(ROOT)/shared
DIAGRAMS := diagrams
MMD_SRCS := $(wildcard $(DIAGRAMS)/*.mmd)
MMD_SVGS := $(MMD_SRCS:.mmd=.svg)
SVG_DEPS := $(MMD_SVGS) $(wildcard $(SHARED)/*.svg)

TALK_SRC := talk/slides.md
TALK_PDF := talk/slides.pdf
TALK_HTML := talk/slides.html

$(DIAGRAMS)/%.svg: $(DIAGRAMS)/%.mmd
	mmdc -i $< -o $@ -b transparent

.PHONY: all talk clean diagrams

all: talk

diagrams: $(MMD_SVGS)

talk: $(TALK_PDF) $(TALK_HTML)

$(TALK_PDF): $(TALK_SRC) $(SVG_DEPS)
	npx @marp-team/marp-cli $< --pdf --allow-local-files -o $@

$(TALK_HTML): $(TALK_SRC) $(SVG_DEPS)
	npx @marp-team/marp-cli $< --allow-local-files -o $@

clean:
	rm -f $(TALK_PDF) $(TALK_HTML)
