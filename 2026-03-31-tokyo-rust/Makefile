ROOT := ..
SHARED := $(ROOT)/shared
DIAGRAMS := diagrams
SVG_DEPS := $(wildcard $(DIAGRAMS)/*.svg) $(wildcard $(SHARED)/*.svg)

# Marp slides
TALK_SRC := talk/slides-v2.md
TALK_PDF := talk/slides-v2.pdf
TALK_HTML := talk/slides-v2.html

# Typst slides
TALK_TYPST_SRC := talk-typst/slides.typ
TALK_TYPST_PDF := talk-typst/slides.pdf

# Poster
POSTER_SRC := poster/poster.typ
POSTER_PDF := poster/poster.pdf

.PHONY: all talk talk-typst poster clean

all: talk talk-typst poster

talk: $(TALK_PDF) $(TALK_HTML)

talk-typst: $(TALK_TYPST_PDF)

poster: $(POSTER_PDF)

$(TALK_PDF): $(TALK_SRC) $(SVG_DEPS)
	npx @marp-team/marp-cli $< --pdf --allow-local-files -o $@

$(TALK_HTML): $(TALK_SRC) $(SVG_DEPS)
	npx @marp-team/marp-cli $< --allow-local-files -o $@

$(TALK_TYPST_PDF): $(TALK_TYPST_SRC) $(SVG_DEPS)
	typst compile $< $@ --root $(ROOT)

$(POSTER_PDF): $(POSTER_SRC) $(SVG_DEPS)
	typst compile $< $@ --root $(ROOT)

clean:
	rm -f $(TALK_PDF) $(TALK_HTML) $(TALK_TYPST_PDF) $(POSTER_PDF)
