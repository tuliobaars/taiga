#!/usr/bin/env python3
"""Write man/*.Rd and NAMESPACE from the roxygen comments in R/ (roxygen2 was not available where the package
was made). The roxygen comments stay the source of truth: with R available, `devtools::document()`
regenerates both files from the same comments (DESCRIPTION has `Roxygen: list(markdown = TRUE)`).

Supported: title / description / details paragraphs, @description, @details, @param, @inheritParams,
@return / @returns, @examples, @seealso, @export, @keywords, @noRd, "_PACKAGE"; markdown: `code`,
[fun()], [pkg::fun()], **bold**, *italic*, <url>, "- " bullet lists.

    python3 tools/document.py
"""
import os, re, sys

PKG_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG = re.search(r"^Package:\s*(\S+)", open(os.path.join(PKG_DIR, "DESCRIPTION")).read(), re.M).group(1)


def blocks():
    """(roxygen lines, the code line that follows, file) for every block in R/"""
    out = []
    for f in sorted(os.listdir(os.path.join(PKG_DIR, "R"))):
        if not f.endswith(".R"): continue
        lines = open(os.path.join(PKG_DIR, "R", f), encoding="utf-8").read().split("\n")
        i = 0
        while i < len(lines):
            if lines[i].startswith("#'"):
                j = i
                while j < len(lines) and lines[j].startswith("#'"): j += 1
                rox = [l[2:][1:] if l[2:3] == " " else l[2:] for l in lines[i:j]]
                code = "\n".join(lines[j:j + 40])
                out.append((rox, code, f)); i = j
            else:
                i += 1
    return out


def signature(code):
    """name and argument text of `name <- function(...)`, or "_PACKAGE" """
    if code.lstrip().startswith('"_PACKAGE"'): return "_PACKAGE", None
    m = re.match(r"\s*([A-Za-z_.][A-Za-z0-9_.]*)\s*<-\s*function\s*\(", code)
    if not m: return None, None
    i = m.end(); depth = 1; quote = None; k = i
    while depth:
        c = code[k]
        if quote:
            if c == "\\": k += 1
            elif c == quote: quote = None
        elif c in "\"'": quote = c
        elif c == "(": depth += 1
        elif c == ")": depth -= 1
        k += 1
    args = re.sub(r"\s+", " ", code[i:k - 1]).strip()
    return m.group(1), args


def parse(rox):
    d = {"title": None, "desc": [], "details": [], "params": [], "inherit": [], "return": [], "examples": [], "seealso": [],
         "export": False, "keywords": [], "noRd": False}
    paras, cur, tag = [], [], None
    for line in rox + ["@end"]:
        m = re.match(r"@(\w+)\s?(.*)$", line)
        if m:
            if tag is None:
                if cur: paras.append(cur)
            else:
                flush(d, tag, cur)
            tag, rest = m.group(1), m.group(2); cur = [rest] if rest else []
            if tag in ("export", "noRd"): d[tag] = True; tag_done = True
            continue
        if tag is None:
            if line.strip() == "":
                if cur: paras.append(cur); cur = []
            else: cur.append(line)
        else:
            cur.append(line)
    if paras: d["title"] = " ".join(paras[0]).strip()
    d["desc"] = paras[1:] + d["desc"]
    return d


def flush(d, tag, cur):
    text = "\n".join(cur).strip("\n")
    if tag == "param":
        name, _, rest = text.partition(" "); d["params"].append((name, re.sub(r"\s+", " ", rest).strip()))
    elif tag == "inheritParams": d["inherit"].append(text.strip())
    elif tag in ("return", "returns"): d["return"].append(text)
    elif tag == "examples": d["examples"].append("\n".join(cur).strip("\n"))
    elif tag == "seealso": d["seealso"].append(text)
    elif tag == "keywords": d["keywords"] += text.split()
    elif tag == "description": d["desc"] += [p.split("\n") for p in re.split(r"\n\s*\n", text)]
    elif tag == "details": d["details"] += [p.split("\n") for p in re.split(r"\n\s*\n", text)]


def md(text):
    """roxygen markdown -> Rd"""
    codes = []
    def keep(m): codes.append(m.group(1)); return "\x00%d\x00" % (len(codes) - 1)
    text = re.sub(r"`([^`]+)`", keep, text)                      # code spans are escaped on their own (code())
    text = text.replace("\\", "\\\\").replace("%", "\\%")
    text = text.replace("{", "\\{").replace("}", "\\}")          # literal braces in prose
    text = re.sub(r"\[([A-Za-z0-9_.]+)::([A-Za-z0-9_.]+)\(\)\]", lambda m: "\\code{\\link[%s:%s]{%s::%s()}}" % (m[1], m[2], m[1], m[2]), text)
    text = re.sub(r"\[([A-Za-z0-9_.]+)\(\)\]", lambda m: "\\code{\\link[=%s]{%s()}}" % (m[1], m[1]), text)
    text = re.sub(r"<(https?://[^>]+)>", r"\\url{\1}", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\\strong{\1}", text)
    text = re.sub(r"(?<![\w*])\*([^*\s][^*]*)\*(?![\w*])", r"\\emph{\1}", text)
    def code(c): return "\\code{%s}" % c.replace("\\", "\\\\").replace("{", "\\{").replace("}", "\\}").replace("%", "\\%")
    return re.sub(r"\x00(\d+)\x00", lambda m: code(codes[int(m[1])]), text)


def paragraphs(paras):
    out = []
    for p in paras:
        lines = [l for l in p]
        if lines and all(re.match(r"^\s*- ", l) or l.startswith("  ") for l in lines) and re.match(r"^\s*- ", lines[0]):
            items, curi = [], []
            for l in lines:
                if re.match(r"^\s*- ", l):
                    if curi: items.append(" ".join(curi))
                    curi = [re.sub(r"^\s*- ", "", l)]
                else: curi.append(l.strip())
            items.append(" ".join(curi))
            out.append("\\itemize{\n" + "\n".join("\\item " + md(x) for x in items) + "\n}")
        else:
            out.append(md(" ".join(l.strip() for l in lines)))
    return "\n\n".join(out)


def main():
    man = os.path.join(PKG_DIR, "man"); os.makedirs(man, exist_ok=True)
    for f in os.listdir(man):
        if f.endswith(".Rd") and open(os.path.join(man, f)).readline().startswith("% Generated by tools/document.py"): os.remove(os.path.join(man, f))
    docs, exports = {}, []
    for rox, code, fname in blocks():
        name, args = signature(code)
        if name is None: continue
        d = parse(rox); d["name"], d["args"], d["file"] = name, args, fname
        if d["export"]: exports.append(name)
        if d["noRd"]: continue
        docs[name] = d
    for name, d in docs.items():                       # @inheritParams
        have = {p for p, _ in d["params"]}
        for src in d["inherit"]:
            for p, t in docs.get(src, {}).get("params", []):
                if p not in have and d["args"] is not None and re.search(r"(^|[\s,])%s\s*(=|,|$)" % re.escape(p), d["args"]):
                    d["params"].append((p, t)); have.add(p)
        if d["args"] is not None:                      # order arguments as in the signature
            order = [a.split("=")[0].strip() for a in re.split(r",(?![^()]*\))", d["args"])]
            def key(p):
                first = p[0].split(",")[0]
                return order.index(first) if first in order else 99
            d["params"].sort(key=key)
    for name, d in docs.items():
        pkg = name == "_PACKAGE"
        rdname = f"{PKG}-package" if pkg else name
        o = ["%% Generated by tools/document.py (roxygen2-compatible, from the comments in R/%s): do not edit by hand" % d["file"],
             "%% Please edit documentation in R/%s." % d["file"], "\\docType{package}" if pkg else None, "\\name{%s}" % rdname]
        o += ["\\alias{%s}" % a for a in ([f"{PKG}-package", PKG] if pkg else [name])]
        o.append("\\title{%s}" % md(d["title"]))
        if not pkg:
            usage = "%s(%s)" % (name, d["args"])
            if len(usage) > 80:
                parts = re.split(r",\s(?![^()]*\))", d["args"])
                usage = "%s(\n  %s\n)" % (name, ",\n  ".join(parts))
            o += ["\\usage{", usage, "}"]
            if d["params"]:
                o.append("\\arguments{")
                o += ["\\item{%s}{%s}" % (p, md(t).replace("\n", " ")) for p, t in d["params"]]
                o.append("}")
        if d["return"]: o += ["\\value{", md(" ".join(l.strip() for l in "\n".join(d["return"]).split("\n"))), "}"]
        o += ["\\description{", paragraphs(d["desc"]) if d["desc"] else md(d["title"]), "}"]
        if d["details"]: o += ["\\details{", paragraphs(d["details"]), "}"]
        if d["examples"]: o += ["\\examples{", "\n".join(e.replace("%", "\\%") for e in d["examples"]), "}"]
        if d["seealso"]: o += ["\\seealso{", md(" ".join(d["seealso"])), "}"]
        o += ["\\keyword{%s}" % k for k in d["keywords"]]
        open(os.path.join(man, rdname + ".Rd"), "w", encoding="utf-8").write("\n".join(x for x in o if x is not None) + "\n")
    ns = ["# Generated by tools/document.py (roxygen2-compatible): do not edit by hand", ""] + ["export(%s)" % e for e in sorted(set(exports))]
    open(os.path.join(PKG_DIR, "NAMESPACE"), "w").write("\n".join(ns) + "\n")
    print("%d Rd files, %d exports" % (len(docs), len(set(exports))))


if __name__ == "__main__":
    sys.exit(main())
