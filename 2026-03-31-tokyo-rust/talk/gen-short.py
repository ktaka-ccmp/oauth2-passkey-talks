#!/usr/bin/env python3
"""Generate slides-v2-short.md from slides-v2-full.md by selecting specific slides."""

FULL_PATH = "talk/slides-v2-full.md"
SHORT_PATH = "talk/slides-v2-short.md"

# (match_string, exclude_string)
# Slides are selected if match_string is found AND exclude_string is not found.
# Order defines the output slide order.
SLIDE_SELECTORS = [
    ("# oauth2-passkey",                        None),
    ("# Live Demo",                             None),
    ("## Demo\n",                               None),
    ("## Motivation",                           None),
    ("## Agenda",                               None),   # content replaced below
    ("# Using the Library",                     None),
    ("## .env Setup (Minimal)",                 None),
    ("## How to Use",                           None),
    ("## Page Protection: AuthUser Extractor",  None),
    ("## Page Protection: Middleware",          "Variants"),  # exclude Variants slide
    ("# Storage & LazyLock Pattern",            None),
    ("## Switch DB by Changing .env",           None),
    ("# Wrap-up",                               None),
    ("## Summary",                              None),
    ("## Thank You",                            None),
]

SHORT_AGENDA = """\
## Agenda
&nbsp;

1. **Using the Library**
2. **Multi-DB Storage Support**
3. **Wrap-up**\
"""


def main():
    with open(FULL_PATH) as f:
        content = f.read()

    # Split on \n---\n: parts[0] = frontmatter (with opening ---), parts[1:] = slides
    parts = content.split("\n---\n")
    frontmatter = parts[0]
    slides = parts[1:]

    selected = []
    for match, exclude in SLIDE_SELECTORS:
        for slide in slides:
            if match in slide and (exclude is None or exclude not in slide):
                if match == "## Agenda":
                    # Replace agenda content
                    import re
                    replaced = re.sub(r"## Agenda.*", SHORT_AGENDA, slide, flags=re.DOTALL)
                    selected.append(replaced)
                else:
                    selected.append(slide)
                break
        else:
            print(f"WARNING: slide not found for selector: {match!r}")

    output = frontmatter + "\n---\n" + "\n---\n".join(selected)

    with open(SHORT_PATH, "w") as f:
        f.write(output)

    print(f"Generated {SHORT_PATH} ({len(selected)} slides from {len(slides)} total)")


if __name__ == "__main__":
    main()
