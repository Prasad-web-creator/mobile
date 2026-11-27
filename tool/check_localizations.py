"""Check the English and Tamil localization catalogs before generating Dart."""

import json
import re
from pathlib import Path


LIB = Path(__file__).resolve().parents[1] / "lib"
CATALOG = LIB / "l10n"
PLACEHOLDER = re.compile(r"{\s*([A-Za-z_]\w*)\s*(?:[,}])")
VISIBLE_LITERAL = re.compile(
    r"""(?:\b(?:Text|TextSpan|SelectableText)\s*\(\s*(?:text:\s*)?"""
    r"""|\b(?:labelText|hintText|helperText|errorText|tooltip|semanticLabel|confirmLabel|cancelLabel)\s*:\s*)"""
    r"""["'][A-Za-z][^"'\n]{2,}"""
)
DISPLAY_ARGUMENT = re.compile(
    r"""\b(?:title|subtitle|message|label|description|placeholder|actionLabel|emptyMessage|statusLabel)"""
    r"""\s*:\s*["'][A-Za-z][^"'\n]{2,}"""
)


def reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate localization key: {key}")
        result[key] = value
    return result


def read_catalog(locale):
    path = CATALOG / f"app_{locale}.arb"
    catalog = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_keys)
    if catalog.get("@@locale") != locale:
        raise ValueError(f"{path.name} must declare locale {locale}")
    return catalog


def main():
    english = read_catalog("en")
    tamil = read_catalog("ta")
    keys = {key for key in english if not key.startswith("@")}
    tamil_keys = {key for key in tamil if not key.startswith("@")}
    if keys != tamil_keys:
        raise ValueError(f"Missing Tamil keys {sorted(keys - tamil_keys)}; extra Tamil keys {sorted(tamil_keys - keys)}")
    for key in sorted(keys):
        for catalog in (english, tamil):
            if not isinstance(catalog[key], str) or not catalog[key].strip():
                raise ValueError(f"Empty or invalid translation for {key} in {catalog['@@locale']}")
        placeholders = english.get(f"@{key}", {}).get("placeholders", {})
        if f"@{key}" in tamil and tamil[f"@{key}"].get("placeholders", placeholders) != placeholders:
            raise ValueError(f"Different placeholder metadata for {key}")
        for catalog in (english, tamil):
            # ICU branch bodies can also start with braces, so Flutter's parser
            # remains responsible for syntax and unexpected arguments.
            missing = set(placeholders) - set(PLACEHOLDER.findall(catalog[key]))
            if missing:
                raise ValueError(f"{catalog['@@locale']} {key} is missing {sorted(missing)}")
    violations = []
    for path in LIB.rglob("*.dart"):
        relative = path.relative_to(LIB)
        if relative.parts[0] in {"l10n", "debug"}:
            continue
        source = path.read_text(encoding="utf-8")
        patterns = [VISIBLE_LITERAL]
        if "presentation" in relative.parts or relative.parts[0] == "core":
            patterns.append(DISPLAY_ARGUMENT)
        for match in (match for pattern in patterns for match in pattern.finditer(source)):
            line = source.count("\n", 0, match.start()) + 1
            violations.append(f"{relative}:{line}")
    if violations:
        raise ValueError("Direct UI string literals found at " + ", ".join(violations))
    print(f"Validated {len(keys)} English and {len(tamil_keys)} Tamil messages and checked direct UI literals.")


if __name__ == "__main__":
    main()
