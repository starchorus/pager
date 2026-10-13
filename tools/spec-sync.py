#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""tools/spec-sync.py -- keep the spec's machine-quoted parts equal to the code.

  python3 tools/spec-sync.py [--check] themes.json contrast.json docs/architecture.md

Between the markers
  <!-- spec-sync:themes:begin --> ... <!-- spec-sync:themes:end -->     three fenced ```json blocks, one per theme: THEMES.<id> literally (one line per top-level key)
  <!-- spec-sync:contrast:begin --> ... <!-- spec-sync:contrast:end -->  a Markdown table: every CONTRAST_PAIRS row with its WCAG ratio in the three themes
the generated text replaces the old one (write mode) or is compared with it (--check: exit 1 on any difference, printing the first differing line).
Both inputs come from tools/dump-themes.sh. No wall clock, no network.
"""
import itertools
import json
import sys

THEMES = (("foundation", "Foundation"), ("wargames", "WarGames"), ("whitehall", "Whitehall"))


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def themes_block(themes):
    out = []
    for tid, _ in THEMES:
        keys = ['  %s: %s' % (json.dumps(k), json.dumps(v, ensure_ascii=False, separators=(", ", ": ")))
                for k, v in themes[tid].items()]
        out += ["```json", "// THEMES.%s" % tid, "{"] + [k + "," for k in keys[:-1]] + keys[-1:] + ["}", "```", ""]
    return "\n".join(out).rstrip("\n") + "\n"


def contrast_block(c):
    out = ["| Foreground | Background | Minimum | Use | " + " | ".join(n for _, n in THEMES) + " |",
           "|---|---|---|---|" + "---|" * len(THEMES)]
    for i, row in enumerate(c[0]):
        cells = ["%.2f%s" % (c[t][i]["ratio"], "" if c[t][i]["pass"] else " ✗") for t in range(3)]
        out.append("| `%s` | `%s` | ≥ %s | %s | %s |" % (row["fg"], row["bg"], "%g" % row["min"], row["what"].replace("|", "/"), " | ".join(cells)))
    return "\n".join(out) + "\n"


def replace(doc, name, body):
    b, e = "<!-- spec-sync:%s:begin -->" % name, "<!-- spec-sync:%s:end -->" % name
    return doc[:doc.index(b) + len(b)] + "\n" + body + doc[doc.index(e):]


def main(argv):
    check = "--check" in argv
    args = [a for a in argv if a != "--check"]
    if len(args) != 3:
        print(__doc__)
        return 2
    themes, contrast = json.loads(read(args[0])), json.loads(read(args[1]))
    path = args[2]
    doc = read(path)
    new = replace(replace(doc, "themes", themes_block(themes)), "contrast", contrast_block(contrast))
    if not check:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new)
        print("spec-sync: wrote %s" % path)
        return 0
    if new == doc:
        print("spec-sync: the spec's token blocks and contrast table equal the code")
        return 0
    for n, (x, y) in enumerate(itertools.zip_longest(doc.splitlines(), new.splitlines(), fillvalue="<end>"), 1):
        if x != y:
            print("spec-sync: first difference at line %d\n  spec: %s\n  code: %s" % (n, x[:200], y[:200]))
            break
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
