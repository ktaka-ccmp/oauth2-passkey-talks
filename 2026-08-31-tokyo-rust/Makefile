.DEFAULT_GOAL := all

ROOT := ..
SHARED := $(ROOT)/shared
DIAGRAMS := diagrams
MMD_SRCS := $(wildcard $(DIAGRAMS)/*.mmd)
MMD_SVGS := $(MMD_SRCS:.mmd=.svg)
SVG_DEPS := $(MMD_SVGS) $(wildcard $(SHARED)/*.svg)
MERMAID_CSS := $(DIAGRAMS)/mermaid.css

# Marp slides (40-minute talk)
TALK_SRC := talk/slides-40min.md
TALK_PDF := talk/slides-40min.pdf
TALK_HTML := talk/slides-40min.html

$(DIAGRAMS)/%.svg: $(DIAGRAMS)/%.mmd $(MERMAID_CSS)
	mmdc -i $< -o $@ -b transparent -C $(MERMAID_CSS)

.PHONY: all talk clean diagrams

diagrams: $(MMD_SVGS)

all: talk

talk: $(TALK_PDF) $(TALK_HTML)

$(TALK_PDF): $(TALK_SRC) $(SVG_DEPS)
	npx @marp-team/marp-cli $< --pdf --allow-local-files -o $@

$(TALK_HTML): $(TALK_SRC) $(SVG_DEPS)
	npx @marp-team/marp-cli $< --allow-local-files -o $@

clean:
	rm -f $(TALK_PDF) $(TALK_HTML)
