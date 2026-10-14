"""Parse FSDA toolbox metadata into an intermediate representation.

See docs/DESIGN-codegen-parser.md for the full specification.
Specs 022, 023, 024 define the individual components.
"""

import argparse
import json
import logging
import re
import sys
from pathlib import Path

log = logging.getLogger("parse_fsda")


def _read_text(path: Path) -> str:
    """Read an FSDA source file. FSDA files use CRLF and are mostly UTF-8."""
    return path.read_text(encoding="utf-8-sig", errors="replace")


# Start of _enumerate_toolbox():

# One function per line in Contents.m:
#   %   tclust   - Computes trimmed clustering ...   - CLUS-RobClaMULT- 2025 Dec 19
# The category can touch the next hyphen with no space ("CLUS-RobClaMULT-"),
# and categories contain hyphens themselves, so splitting on " - " is not
# enough. Anchor on the date at the end instead and take the non-space token
# before it as the category.
_CONTENTS_LINE = re.compile(
    r"^%\s+(?P<name>[A-Za-z]\w*)\s+-\s+(?P<desc>.*?)\s+-\s*"
    r"(?P<category>\S+?)\s*-\s*(?P<date>\d{4}\s+[A-Za-z]{3}\s+\d{1,2})\s*$"
)


def _parse_contents(contents_path: Path, label: str = "") -> dict:
    """Return {function name: category} from one Contents.m file."""
    found = {}
    for line in _read_text(contents_path).splitlines():
        m = _CONTENTS_LINE.match(line)
        if not m or m.group("name") == "Name":  # skip the column header row
            continue
        name = m.group("name")
        if name in found:
            log.warning(
                "%s: %s listed twice, keeping the first", label or contents_path, name
            )
            continue
        found[name] = m.group("category")
    return found


def _enumerate_toolbox(fsda_root: Path) -> list:
    """Walk the FSDA toolbox tree and return the function inventory.

    Discovers Contents.m files per subfolder, records functionSignatures.json
    paths where they exist, and excludes private/ directories.
    Does not open JSON files. See Spec 022.
    """

    if not fsda_root.exists():
        raise FileNotFoundError(f"FSDA root not found: {fsda_root}")
    if not fsda_root.is_dir():
        raise NotADirectoryError(f"FSDA root is not a directory: {fsda_root}")

    entries = []
    for contents in sorted(fsda_root.rglob("Contents.m")):
        folder = contents.parent
        rel = folder.relative_to(fsda_root)
        if "private" in rel.parts:
            continue

        functions = {}
        for name, category in _parse_contents(
            contents, contents.relative_to(fsda_root).as_posix()
        ).items():
            m_rel = rel / f"{name}.m"
            if not (fsda_root / m_rel).is_file():
                log.warning(
                    "%s lists %s but %s does not exist",
                    contents.relative_to(fsda_root).as_posix(),
                    name,
                    m_rel.as_posix(),
                )
            functions[name] = {"m_path": m_rel.as_posix(), "category": category}

        json_file = folder / "functionSignatures.json"
        entries.append(
            {
                "json_path": (rel / json_file.name).as_posix()
                if json_file.is_file()
                else None,
                "functions": functions,
            }
        )
    return entries


# Start of _parse_json_signatures():


def _parse_json_signatures(json_path: Path) -> dict:
    """Parse a single functionSignatures.json, preserving duplicate keys.

    Returns all signatures grouped by function name. Keys starting
    with _ are excluded. See Spec 023.
    """

    def multikeys_hook(pairs):
        d = {}
        # Track keys that we have explicitly converted into a list of duplicates
        dupes = set()

        for k, v in pairs:
            if k in d:
                # If we already marked this key as a duplicate, just append
                if k in dupes:
                    d[k].append(v)
                # Otherwise, wrap the existing value and the new one in a new list
                else:
                    d[k] = [d[k], v]
                    dupes.add(k)
            else:
                d[k] = v
        return d

    with open(json_path, "r", encoding="utf-8") as f:
        raw_data = json.loads(f.read(), object_pairs_hook=multikeys_hook)

    # Filter out system keys and normalize every function entry to a list
    return {
        key: (value if isinstance(value, list) else [value])
        for key, value in raw_data.items()
        if not key.startswith("_")
    }


# Start of _extract_m_prose():

_BEGIN_CODE = "%% Beginning of code"
_SIG_RE = re.compile(
    r"^function\s*(?:\[(?P<multi>[^\]]*)\]\s*=|(?P<single>\w+)\s*=)?\s*\w+\s*\("
)


def _isolate_preamble(m_path: Path) -> tuple[str, list[str]] | None:
    """Return (signature_line, preamble_lines), or None on failure.

    The preamble is everything between the `function` signature line and
    the `%% Beginning of code` marker, with the leading `%` stripped from
    each line. Returns None (and warns) if the file can't be read, doesn't
    start with `function`, or has no marker.
    """
    try:
        text = _read_text(m_path)
    except OSError as exc:
        log.warning(f"_extract_m_prose: cannot read {m_path}: {exc}")
        return None

    lines = text.splitlines()
    if not lines or not lines[0].lstrip().startswith("function"):
        log.warning(f"_extract_m_prose: {m_path} does not start with a 'function' line")
        return None

    end_idx = next(
        (i for i, line in enumerate(lines) if line.strip() == _BEGIN_CODE), None
    )
    if end_idx is None:
        log.warning(f"_extract_m_prose: no '{_BEGIN_CODE}' marker in {m_path}")
        return None

    preamble = [
        line[1:].lstrip(" ") if line.startswith("%") else line
        for line in lines[1:end_idx]
    ]
    return lines[0], preamble


def _extract_output_names(sig_line: str) -> tuple:
    """Return (output_names, has_varargout) from a `function ... = name(...)` line.

    `varargout` never gets a literal entry in the `Output:` section - its
    entries live in `Optional Output:` instead - so it's excluded from the
    returned names but flagged separately.
    """
    match = _SIG_RE.match(sig_line.strip())
    if not match:
        return [], False
    if match.group("multi") is not None:
        names = [n.strip() for n in match.group("multi").split(",") if n.strip()]
    elif match.group("single"):
        names = [match.group("single")]
    else:
        names = []
    return [n for n in names if n != "varargout"], "varargout" in names


def _strip_example_blocks(lines: list) -> list:
    """Drop `%{ ... %}` example blocks.

    After the `%`-strip in `_isolate_preamble`, the delimiters are bare
    lines that are exactly `{` / `}`. The pipeline never captures examples
    (Spec 024).
    """
    result = []
    in_block = False
    for line in lines:
        stripped = line.strip()
        if not in_block and stripped == "{":
            in_block = True
        elif in_block and stripped == "}":
            in_block = False
        elif not in_block:
            result.append(line)
    return result


_SECTION_ORDER = [
    ("docsearch", re.compile(r"docsearchFS\(")),
    ("required_input", re.compile(r"^\s*Required input arguments\s*:", re.IGNORECASE)),
    ("optional_input", re.compile(r"^\s*Optional input arguments\s*:", re.IGNORECASE)),
    ("output", re.compile(r"^\s*Output\s*:", re.IGNORECASE)),
    ("optional_output", re.compile(r"^\s*Optional\s+Output\s*:", re.IGNORECASE)),
    ("more_about", re.compile(r"^\s*More\s+About\s*:", re.IGNORECASE)),
    ("see_also", re.compile(r"^\s*See\s+also\s*:?", re.IGNORECASE)),
    ("references", re.compile(r"^\s*References\s*:?", re.IGNORECASE)),
]


def _find_section_bounds(lines: list) -> dict:
    """Return {section_name: line_index} for each header found, in the
    fixed publishFS order. A header absent from the file (e.g. no
    `Optional Output:`) is simply absent from the result. `docsearch`
    marks the start of the long description, not a real section.
    """
    bounds = {}
    start = 0
    for name, pattern in _SECTION_ORDER:
        idx = next(
            (i for i in range(start, len(lines)) if pattern.search(lines[i])), None
        )
        if idx is not None:
            bounds[name] = idx
            start = idx + 1
    return bounds


def _section_lines(lines: list, bounds: dict, name: str) -> list:
    """Body of section `name`: between its header (exclusive) and the next
    found header (exclusive), or end of `lines`. `[]` if `name` wasn't found.
    """
    if name not in bounds:
        return []
    order = [n for n, _ in _SECTION_ORDER]
    start = bounds[name] + 1
    later = [bounds[n] for n in order[order.index(name) + 1 :] if n in bounds]
    end = min(later) if later else len(lines)
    return lines[start:end]


def _extract_long_desc(lines: list, bounds: dict) -> str:
    """Prose between the docsearchFS link and `Required input arguments:`,
    collapsed to one whitespace-normalized string.
    """
    body = _section_lines(lines, bounds, "docsearch")
    text = " ".join(line.strip() for line in body if line.strip())
    return re.sub(r"\s+", " ", text).strip()


_NAME_BLOCK_RE = re.compile(r"^\s*(\w+)\s*:\s*(.*)$")

# publishFS convention words that use the same `Word:` shape as a real
# parameter/output name but are inline sub-notes, not names of their own
# (verified against occurrences across the whole FSDA toolbox, not just
# these 3 files - both appear repeatedly mid-description, e.g. "Remark:
# this output is present only if ..."). Without this, they'd wrongly cut
# off whatever param/output was being accumulated and start a bogus entry.
_NON_NAME_WORDS = {"remark", "example"}


def _parse_named_blocks(
    lines: list, pattern=_NAME_BLOCK_RE, exclude=_NON_NAME_WORDS
) -> dict:
    """Split a section's body into blocks keyed by a leading `name :` line.

    Shared by `params`/top-level `outputs` (default `pattern`, a bare
    `name :`) and struct `fields` (called with an `out\\.(\\w+)\\s*=`
    pattern): a struct field line like `out.muopt= ...` has a dot before
    its `=`, not a bare `:`, so it never starts a new block under the
    default pattern - it folds into whatever block is currently open as a
    continuation line instead, which is exactly the split the field-level
    call needs its own turn at.
    """
    blocks = {}
    current = None
    for raw in lines:
        match = pattern.match(raw)
        if match and match.group(1).lower() not in exclude:
            current = match.group(1)
            first = match.group(2).strip()
            blocks[current] = [first] if first else []
        elif current is not None:
            stripped = raw.strip()
            if stripped:
                blocks[current].append(stripped)
    return blocks


def _join_block(fragments: list) -> str:
    return re.sub(r"\s+", " ", " ".join(fragments)).strip()


def _extract_params(lines: list, bounds: dict) -> dict:
    """Merge Required + Optional input sections into one flat params dict."""
    params = {}
    for section in ("required_input", "optional_input"):
        blocks = _parse_named_blocks(_section_lines(lines, bounds, section))
        for name, fragments in blocks.items():
            params[name] = _join_block(fragments)
    return params


def _extract_see_also(lines: list, bounds: dict) -> list:
    """Comma-separated function names. The list lives on the header's own
    line (`See also: tkmeans, tclustIC, tclusteda`), not a separate body
    line, so this reads the header line directly rather than `_section_lines`.
    """
    if "see_also" not in bounds:
        return []
    header_line = lines[bounds["see_also"]]
    match = re.search(r"See\s+also\s*:?\s*(.*)", header_line, re.IGNORECASE)
    if not match:
        return []
    return [item.strip() for item in match.group(1).split(",") if item.strip()]


def _extract_references(lines: list, bounds: dict) -> list:
    if "references" not in bounds:
        return []
    reference_lines = _section_lines(lines, bounds, "references")
    copyright_idx = next(
        (
            i
            for i, line in enumerate(reference_lines)
            if line.strip().lower().startswith("copyright")
        ),
        len(reference_lines),
    )
    reference_lines = reference_lines[:copyright_idx]

    references = []
    current = []
    for line in reference_lines:
        stripped = line.strip()
        if stripped:
            current.append(stripped)
        elif current:
            references.append(_join_block(current))
            current = []
    if current:
        references.append(_join_block(current))
    return references


def _split_output_fields(output_name: str, fragments: list, field_re) -> dict:
    """Like `_parse_named_blocks`, but a repeated field name continues the
    current field (with a warning) instead of restarting it.
    """
    blocks = {}
    current = None
    for raw in fragments:
        match = field_re.match(raw)
        if match and match.group(1) not in blocks:
            current = match.group(1)
            first = match.group(2).strip()
            blocks[current] = [first] if first else []
        elif current is not None:
            # Any other line belongs to the current field includign repetitions
            if match:
                log.warning(
                    "field %s repeats in output %s; treating as continuation",
                    match.group(1),
                    output_name,
                )
            stripped = raw.strip()
            if stripped:
                blocks[current].append(stripped)
    return blocks


def _build_output_entry(name: str, fragments: list) -> dict:
    field_re = re.compile(rf"^\s*{re.escape(name)}\.(\w+)\s*=\s*(.*)$")
    field_blocks = _split_output_fields(name, fragments, field_re)
    fields = [
        {"name": field_name, "desc": _join_block(field_fragments)}
        for field_name, field_fragments in field_blocks.items()
    ]

    if fields:
        first_field_idx = next(
            i for i, line in enumerate(fragments) if field_re.match(line)
        )
        prose_fragments = fragments[:first_field_idx]
    else:
        prose_fragments = fragments
    long_desc = _join_block(prose_fragments)
    split = long_desc.find(". ")
    short_desc = long_desc[: split + 1] if split != -1 else long_desc

    return {
        "name": name,
        "short_desc": short_desc,
        "long_desc": long_desc,
        "fields": fields,
    }


def _extract_outputs(lines: list, bounds: dict, has_varargout: bool) -> list:
    outputs = []
    output_blocks = _parse_named_blocks(_section_lines(lines, bounds, "output"))
    for name, fragments in output_blocks.items():
        outputs.append(_build_output_entry(name, fragments))

    if has_varargout:
        optional_blocks = _parse_named_blocks(
            _section_lines(lines, bounds, "optional_output")
        )
        for name, fragments in optional_blocks.items():
            outputs.append(_build_output_entry(name, fragments))

    return outputs


def _extract_m_prose(m_path: Path) -> dict | None:
    """Extract prose from a single .m file's preamble.

    Returns long description, per-parameter descriptions, outputs,
    see-also references, and citations. See Spec 024.
    """
    isolated = _isolate_preamble(m_path)
    if isolated is None:
        return None
    sig_line, preamble = isolated
    _, has_varargout = _extract_output_names(sig_line)
    preamble = _strip_example_blocks(preamble)
    bounds = _find_section_bounds(preamble)
    long_desc = _extract_long_desc(preamble, bounds)
    params = _extract_params(preamble, bounds)
    outputs = _extract_outputs(preamble, bounds, has_varargout)

    see_also = _extract_see_also(preamble, bounds)

    references = _extract_references(preamble, bounds)

    return {
        "long_desc": long_desc,
        "params": params,
        "outputs": outputs,
        "see_also": see_also,
        "references": references,
    }


# Start of the orchestrator (main()):

_FSDA_URL = "https://rosa.unipr.it/FSDA/{name}.html"


def _normalize_matlab_type(value) -> list:
    """Normalize one JSON type spec to list-of-lists (OR of AND).

    `"struct"` and `["numeric", "scalar"]` both become a single-element
    or two-element inner list. `struct:Name` references collapse to
    `struct`; the typedef is not resolved here. `choices=...` hints are
    kept verbatim for codegen to interpret later.
    """

    def clean(atom: str) -> str:
        return "struct" if atom.startswith("struct:") else atom

    atoms = value if isinstance(value, list) else [value]

    if all(isinstance(a, list) for a in atoms):
        clauses = [[clean(s) for s in sublist] for sublist in atoms]
    else:
        clauses = [[clean(atom) for atom in atoms]]

    # Remove duplicates `struct` while keeping order
    return [list(c) for c in dict.fromkeys(map(tuple, clauses))]


def _union_types(first: list, second: list) -> list:
    """Union two normalized type specs, keeping first-seen order."""
    merged = list(first)
    for entry in second:
        if entry not in merged:
            merged.append(entry)
    return merged


def _merge_inputs(entries: list) -> list:
    """Flatten the `inputs` of every signature entry into one list.

    Order follows the first entry; parameters unique to a later entry are
    appended. Types are unioned across entries; `kind`, `default` and
    `purpose` come from the first entry that declares the parameter.
    """
    by_name = {}
    order = []
    for entry in entries:
        for param in entry.get("inputs") or []:
            name = param.get("name")
            if name is None:
                log.warning("Skipping an input with no name: %r", param)
                continue
            if name not in by_name:
                order.append(name)
                by_name[name] = {
                    "name": name,
                    "kind": param.get("kind"),
                    "matlab_type": _normalize_matlab_type(param.get("type")),
                    "purpose_short": param.get("purpose"),
                    "default": param.get("default"),
                }
                continue
            by_name[name]["matlab_type"] = _union_types(
                by_name[name]["matlab_type"],
                _normalize_matlab_type(param.get("type")),
            )
    return [by_name[name] for name in order]


def _validate_input_types(name: str, entries: list) -> bool:
    """Reject a function if any individual signature has an untyped input."""
    valid = True
    for signature_index, entry in enumerate(entries, start=1):
        for param in entry.get("inputs") or []:
            if "type" not in param or param.get("type") is None:
                input_name = param.get("name", "<unnamed>")
                log.warning(
                    "%s: input %s has no type in signature %d; skipping function",
                    name,
                    input_name,
                    signature_index,
                )
                valid = False
    return valid


def _merge_outputs(entries: list) -> list:
    """Take outputs from the first entry, normalizing each `matlab_type`."""
    if not entries:
        return []
    return [
        {
            "name": output.get("name"),
            "matlab_type": (
                None
                if "type" not in output or output.get("type") is None
                else _normalize_matlab_type(output["type"])
            ),
            "short_desc": None,
            "long_desc": None,
            "fields": [],
        }
        for output in entries[0].get("outputs") or []
    ]


def _warn_mismatch(fn_name: str, kind: str, json_names: set, prose_names: set) -> None:
    """Log names present on one side (JSON or .m preamble) but not the other."""
    for item in sorted(json_names - prose_names):
        log.warning("%s: %s %s is in JSON but not the .m preamble", fn_name, kind, item)
    for item in sorted(prose_names - json_names):
        log.warning(
            "%s: %s %s is in the .m preamble but not the JSON", fn_name, kind, item
        )


def _attach_param_prose(name: str, inputs: list, prose_params: dict) -> None:
    for param in inputs:
        param["purpose_long"] = prose_params.get(param["name"])

    _warn_mismatch(
        name,
        "parameter",
        {p["name"] for p in inputs},
        set(prose_params),
    )


def _attach_output_prose(name: str, outputs: list, prose_output_list: list) -> None:
    # Index by name so lookups match the params path; warn on duplicates
    # instead of silently letting the last one win.
    prose_outputs = {}
    for prose_output in prose_output_list:
        output_name = prose_output["name"]
        if output_name in prose_outputs:
            log.warning(
                "%s: output %s appears more than once in the .m preamble",
                name,
                output_name,
            )
        prose_outputs[output_name] = prose_output

    for output in outputs:
        source = prose_outputs.get(output["name"])
        if source is None:
            continue
        output["short_desc"] = source.get("short_desc")
        output["long_desc"] = source.get("long_desc")
        output["fields"] = source.get("fields") or []

    _warn_mismatch(
        name,
        "output",
        {o["name"] for o in outputs},
        set(prose_outputs),
    )


def _build_ir_record(
    name: str, entries: list, prose: dict, category: str
) -> dict | None:
    """Merge one function's JSON signatures and .m prose into an IR record.

    The JSON is the hard dependency and drives the parameter and output
    lists; prose only fills in the `*_long` fields and output prose.
    Missing prose leaves those fields null (docs section 3.4).
    """
    prose = prose or {}
    if not _validate_input_types(name, entries):
        return None

    inputs = _merge_inputs(entries)
    outputs = _merge_outputs(entries)

    _attach_param_prose(name, inputs, prose.get("params") or {})
    _attach_output_prose(name, outputs, prose.get("outputs") or [])

    return {
        "name": name,
        "category": category,
        "description_short": entries[0].get("description") if entries else None,
        "description_long": prose.get("long_desc"),
        "inputs": inputs,
        "outputs": outputs,
        "see_also": prose.get("see_also") or [],
        "references": prose.get("references") or [],
        "fsda_url": _FSDA_URL.format(name=name),
    }


def main(args) -> int:
    """Run the full pipeline and write the IR to `args.output`.

    Enumerate the toolbox, then for every folder that has a
    functionSignatures.json parse it, cross-check against that folder's
    Contents.m functions, and extract .m prose only for the functions
    present in both. Returns a process exit code.
    """
    fsda_root = args.fsda_root
    try:
        folders = _enumerate_toolbox(fsda_root)
    except (FileNotFoundError, NotADirectoryError) as exc:
        log.error("%s", exc)
        return 1

    records = []

    for folder in folders:
        functions = folder["functions"]
        json_path = folder["json_path"]

        # Skip folders that have no JSON file. The IR is driven by the JSON, so
        # we don't want to include any functions that are only in Contents.m.
        if json_path is None:
            log.warning(
                "%s: no functionSignatures.json, skipping %d function(s)",
                json_path or fsda_root,
                len(functions),
            )
            continue

        try:
            signatures = _parse_json_signatures(fsda_root / json_path)
        except (OSError, ValueError) as exc:
            log.error("%s: cannot parse signatures: %s", json_path, exc)
            continue

        for name in sorted(functions):
            if name not in signatures:
                log.warning("%s: no JSON entry, skipping", name)
                continue

            m_path = fsda_root / functions[name]["m_path"]

            if not m_path.is_file():
                log.warning("%s: .m file not found, skipping", name)
                continue

            prose = _extract_m_prose(m_path)
            if prose is None:
                log.warning("%s: no usable .m prose, JSON only", name)

            record = _build_ir_record(
                name, signatures[name], prose, functions[name]["category"]
            )
            if record is not None:
                records.append(record)

    # Write the IR to disk.
    output = args.output

    # If the user specified a directory, write to IntRep.json inside it.
    if output.suffix != ".json":
        output = output / "IntRep.json"

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(records, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Parse FSDA metadata into an intermediate representation.",
    )
    parser.add_argument(
        "--fsda-root",
        type=Path,
        required=True,
        help="Path to the FSDA toolbox root directory",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("IntRep.json"),
        help="Where should the output be written (default: ./IntRep.json)",
    )
    args = parser.parse_args()
    sys.exit(main(args))
