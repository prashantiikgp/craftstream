"""Turn the human-readable YAML specs into code for both sides.

    specs/models/*.yaml + specs/api/endpoints.yaml
        -> specs/build/schema.json            (JSON Schema, single source of truth)
        -> backend/app/generated/models.py    (Pydantic models for FastAPI)
        -> app/lib/generated/models.dart      (Dart models for Flutter)
        -> app/lib/generated/api_client.dart  (Dart HTTP client)

Run with:  python tools/codegen.py   (or `make gen`)
Never edit the generated files by hand; edit the YAML and regenerate.
"""

from __future__ import annotations

import json
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SPECS = ROOT / "specs"
HEADER = "GENERATED FROM specs/ BY tools/codegen.py. DO NOT EDIT BY HAND."


# ---------------------------------------------------------------- loading

def load_models() -> dict[str, dict]:
    models = {}
    for path in sorted((SPECS / "models").glob("*.yaml")):
        spec = yaml.safe_load(path.read_text())
        models[spec["model"]] = spec
    return models


def load_api() -> dict:
    return yaml.safe_load((SPECS / "api" / "endpoints.yaml").read_text())


def create_fields(spec: dict) -> dict:
    """Fields a client sends when creating: everything except readonly ones."""
    return {k: v for k, v in spec["fields"].items() if not v.get("readonly")}


# ---------------------------------------------------------------- JSON Schema

def field_schema(f: dict) -> dict:
    t = f["type"]
    if t == "enum":
        s: dict = {"type": "string", "enum": f["values"]}
    elif t == "datetime":
        s = {"type": "string", "format": "date-time"}
    elif t == "array":
        s = {"type": "array", "items": {"type": f.get("items", "string")}}
        if "max_items" in f:
            s["maxItems"] = f["max_items"]
    else:
        s = {"type": t}
    for yk, jk in [("min_length", "minLength"), ("max_length", "maxLength"),
                   ("minimum", "minimum"), ("maximum", "maximum"), ("default", "default")]:
        if yk in f:
            s[jk] = f[yk]
    if f.get("nullable"):
        s["type"] = [s["type"], "null"]
    if f.get("readonly"):
        s["readOnly"] = True
    return s


def build_schema(models: dict) -> dict:
    defs = {}
    for name, spec in models.items():
        defs[name] = {
            "type": "object",
            "description": spec.get("description", ""),
            "properties": {k: field_schema(v) for k, v in spec["fields"].items()},
            "required": list(spec["fields"].keys()),
        }
        cf = create_fields(spec)
        defs[f"{name}Create"] = {
            "type": "object",
            "properties": {k: field_schema(v) for k, v in cf.items()},
            "required": [k for k, v in cf.items() if v.get("required")],
        }
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$defs": defs}


# ---------------------------------------------------------------- Python (Pydantic)

PY_TYPES = {"string": "str", "integer": "int", "number": "float", "boolean": "bool", "datetime": "datetime"}


def py_type(f: dict) -> str:
    t = f["type"]
    if t == "enum":
        base = "Literal[" + ", ".join(repr(v) for v in f["values"]) + "]"
    elif t == "array":
        base = f"list[{PY_TYPES[f.get('items', 'string')]}]"
    else:
        base = PY_TYPES[t]
    return f"{base} | None" if f.get("nullable") else base


def py_field(name: str, f: dict, create: bool) -> str:
    args = []
    if create and f.get("required"):
        args.append("...")
    elif "default" in f:
        d = f["default"]
        args.append("default_factory=list" if d == [] else f"default={d!r}")
    elif f.get("nullable"):
        args.append("default=None")
    else:
        args.append("...")
    for yk, pk in [("min_length", "min_length"), ("max_length", "max_length"),
                   ("minimum", "ge"), ("maximum", "le"), ("max_items", "max_length")]:
        if yk in f:
            args.append(f"{pk}={f[yk]!r}")
    return f"    {name}: {py_type(f)} = Field({', '.join(args)})"


def build_python(models: dict, api: dict) -> str:
    out = [f'"""{HEADER}"""', "", "from __future__ import annotations", "",
           "from datetime import datetime", "from typing import Literal", "",
           "from pydantic import BaseModel, Field", ""]
    for name, spec in models.items():
        out += ["", f"class {name}(BaseModel):", f'    """{spec.get("description", "")}"""', ""]
        out += [py_field(k, v, create=False) for k, v in spec["fields"].items()]
        out += ["", "", f"class {name}Create(BaseModel):",
                f'    """Body for creating a {name} (server-set fields excluded)."""', ""]
        out += [py_field(k, v, create=True) for k, v in create_fields(spec).items()]
        out.append("")
    for tname, fields in api.get("types", {}).items():
        out += ["", f"class {tname}(BaseModel):"]
        for k, t in fields.items():
            out.append(f"    {k}: {PY_TYPES.get(t, t)}")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


# ---------------------------------------------------------------- Dart

DART_TYPES = {"string": "String", "integer": "int", "number": "double", "boolean": "bool",
              "datetime": "DateTime", "enum": "String"}


def dart_type(f: dict) -> str:
    t = f["type"]
    base = f"List<{DART_TYPES[f.get('items', 'string')]}>" if t == "array" else DART_TYPES[t]
    return base + "?" if f.get("nullable") else base


def dart_from_json(name: str, f: dict) -> str:
    j = f"json['{name}']"
    t = f["type"]
    if t == "datetime":
        expr = f"DateTime.parse({j} as String)"
    elif t == "number":
        expr = f"({j} as num).toDouble()"
    elif t == "array":
        expr = f"(({j} ?? []) as List).cast<{DART_TYPES[f.get('items', 'string')]}>()"
    else:
        expr = f"{j} as {DART_TYPES[t]}"
    if f.get("nullable"):
        return f"{j} == null ? null : {expr.replace(' as String)', ' as String)')}"
    return expr


def dart_to_json(name: str, f: dict) -> str:
    if f["type"] == "datetime":
        return f"{name}{'?' if f.get('nullable') else ''}.toIso8601String()"
    return name


def camel(s: str) -> str:
    head, *rest = s.split("_")
    return head + "".join(p.capitalize() for p in rest)


def dart_class(cls: str, fields: dict, doc: str) -> list[str]:
    out = [f"/// {doc}", f"class {cls} {{"]
    for k, f in fields.items():
        out.append(f"  final {dart_type(f)} {camel(k)};")
    out += ["", f"  const {cls}({{"]
    for k, f in fields.items():
        req = "" if f.get("nullable") else "required "
        out.append(f"    {req}this.{camel(k)},")
    out += ["  });", "", f"  factory {cls}.fromJson(Map<String, dynamic> json) => {cls}("]
    for k, f in fields.items():
        out.append(f"        {camel(k)}: {dart_from_json(k, f)},")
    out += ["      );", "", "  Map<String, dynamic> toJson() => {"]
    for k, f in fields.items():
        out.append(f"        '{k}': {dart_to_json(camel(k), f)},")
    out += ["      };", "}", ""]
    return out


def build_dart_models(models: dict, api: dict) -> str:
    out = [f"// {HEADER}", "// ignore_for_file: type=lint", ""]
    for name, spec in models.items():
        out += dart_class(name, spec["fields"], spec.get("description", ""))
        out += dart_class(f"{name}Create", create_fields(spec), f"Body for creating a {name}.")
    for tname, fields in api.get("types", {}).items():
        out.append(f"class {tname} {{")
        for k, t in fields.items():
            out.append(f"  final {DART_TYPES.get(t, t)} {camel(k)};")
        out += ["", f"  const {tname}({{" + ", ".join(f"required this.{camel(k)}" for k in fields) + "});", "",
                f"  factory {tname}.fromJson(Map<String, dynamic> json) => {tname}("]
        for k, t in fields.items():
            expr = f"{t}.fromJson(json['{k}'] as Map<String, dynamic>)" if t in models else f"json['{k}'] as {DART_TYPES.get(t, t)}"
            out.append(f"        {camel(k)}: {expr},")
        out += ["      );", "}", ""]
    return "\n".join(out)


def build_dart_client(api: dict) -> str:
    out = [f"// {HEADER}", "// ignore_for_file: type=lint", "",
           "import 'dart:convert';", "", "import 'package:http/http.dart' as http;", "",
           "import 'models.dart';", "",
           "class ApiException implements Exception {",
           "  final int statusCode;", "  final String body;",
           "  ApiException(this.statusCode, this.body);",
           "  @override", "  String toString() => 'ApiException($statusCode): $body';", "}", "",
           "class ApiClient {", "  final String baseUrl;", "  final http.Client _http;", "",
           f"  ApiClient(String host, {{http.Client? client}})",
           f"      : baseUrl = '$host{api['base_path']}',",
           "        _http = client ?? http.Client();", "",
           "  dynamic _decode(http.Response r) {",
           "    if (r.statusCode >= 400) throw ApiException(r.statusCode, r.body);",
           "    return jsonDecode(utf8.decode(r.bodyBytes));", "  }", ""]
    for ep in api["endpoints"]:
        path = ep["path"]
        params = [seg[1:-1] for seg in path.split("/") if seg.startswith("{")]
        args = [f"String {camel(p)}" for p in params]
        if "body" in ep:
            args.append(f"{ep['body']} body")
        query = ep.get("query", {})
        named = [f"String? {camel(q)}" for q in query]
        sig = ", ".join(args)
        if named:
            sig += (", " if sig else "") + "{" + ", ".join(named) + "}"
        ret = ep["returns"]
        is_list = ret.endswith("[]")
        rtype = f"List<{ret[:-2]}>" if is_list else ret
        dart_path = path
        for p in params:
            dart_path = dart_path.replace("{" + p + "}", "$" + camel(p))
        out.append(f"  /// {ep.get('summary', '')}")
        out.append(f"  Future<{rtype}> {ep['name']}({sig}) async {{")
        if query:
            qmap = ", ".join(f"if ({camel(q)} != null) '{q}': {camel(q)}" for q in query)
            out.append(f"    final uri = Uri.parse('$baseUrl{dart_path}').replace(queryParameters: {{{qmap}}});")
        else:
            out.append(f"    final uri = Uri.parse('$baseUrl{dart_path}');")
        m = ep["method"].lower()
        if "body" in ep:
            out.append(f"    final r = await _http.{m}(uri, headers: {{'Content-Type': 'application/json'}}, body: jsonEncode(body.toJson()));")
        else:
            out.append(f"    final r = await _http.{m}(uri);")
        if is_list:
            out.append(f"    return (_decode(r) as List).map((e) => {ret[:-2]}.fromJson(e as Map<String, dynamic>)).toList();")
        else:
            out.append(f"    return {ret}.fromJson(_decode(r) as Map<String, dynamic>);")
        out += ["  }", ""]
    out.append("}")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- main

def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    print(f"  wrote {path.relative_to(ROOT)}")


def main() -> None:
    models, api = load_models(), load_api()
    print("Generating code from specs/ ...")
    write(SPECS / "build" / "schema.json", json.dumps(build_schema(models), indent=2) + "\n")
    write(ROOT / "backend" / "app" / "generated" / "models.py", build_python(models, api))
    write(ROOT / "backend" / "app" / "generated" / "__init__.py", "")
    write(ROOT / "app" / "lib" / "generated" / "models.dart", build_dart_models(models, api))
    write(ROOT / "app" / "lib" / "generated" / "api_client.dart", build_dart_client(api))
    print("Done.")


if __name__ == "__main__":
    main()
