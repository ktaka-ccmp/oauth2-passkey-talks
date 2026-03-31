ROOT := ..
SHARED := $(ROOT)/shared
DIAGRAMS := diagrams
SVG_DEPS := $(wildcard $(DIAGRAMS)/*.svg) $(wildcard $(SHARED)/*.svg)

# Marp slides (full)
TALK_SRC := talk/slides-v2-full.md
TALK_PDF := talk/slides-v2-full.pdf
TALK_HTML := talk/slides-v2-full.html

# Marp slides (short)
TALK_SHORT_SRC := talk/slides-v2-short.md
TALK_SHORT_PDF := talk/slides-v2-short.pdf
TALK_SHORT_HTML := talk/slides-v2-short.html

# Typst slides
TALK_TYPST_SRC := talk-typst/slides.typ
TALK_TYPST_PDF := talk-typst/slides.pdf

# Poster
POSTER_SRC := poster/poster.typ
POSTER_PDF := poster/poster.pdf

.PHONY: all talk talk-short talk-typst poster clean

all: talk talk-short talk-typst poster

talk: $(TALK_PDF) $(TALK_HTML)

talk-short: $(TALK_SHORT_PDF) $(TALK_SHORT_HTML)

$(TALK_SHORT_SRC): $(TALK_SRC) talk/gen-short.py
	python3 talk/gen-short.py

talk-typst: $(TALK_TYPST_PDF)

poster: $(POSTER_PDF)

$(TALK_PDF): $(TALK_SRC) $(SVG_DEPS)
	npx @marp-team/marp-cli $< --pdf --allow-local-files -o $@

$(TALK_HTML): $(TALK_SRC) $(SVG_DEPS)
	npx @marp-team/marp-cli $< --allow-local-files -o $@

$(TALK_SHORT_PDF): $(TALK_SHORT_SRC) $(SVG_DEPS)
	npx @marp-team/marp-cli $< --pdf --allow-local-files -o $@

$(TALK_SHORT_HTML): $(TALK_SHORT_SRC) $(SVG_DEPS)
	npx @marp-team/marp-cli $< --allow-local-files -o $@

$(TALK_TYPST_PDF): $(TALK_TYPST_SRC) $(SVG_DEPS)
	typst compile $< $@ --root $(ROOT)

$(POSTER_PDF): $(POSTER_SRC) $(SVG_DEPS)
	typst compile $< $@ --root $(ROOT)

clean:
	rm -f $(TALK_PDF) $(TALK_HTML) $(TALK_SHORT_PDF) $(TALK_SHORT_HTML) $(TALK_TYPST_PDF) $(POSTER_PDF)
