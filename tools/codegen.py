"""Turn the human-readable data models into code for both sides.

    models/*.yml + models/endpoints.yml
        -> models/build/schema.json                     (JSON Schema)
        -> backend/app/generated/models.py              (Pydantic models for FastAPI)
        -> backend/app/generated/api.py                 (the API base path; models/ is not in the server image)
        -> frontend/lib/data/generated/models.dart      (Dart models for Flutter)
        -> frontend/lib/data/generated/api_client.dart  (Dart HTTP client, public endpoints only)
        -> frontend/lib/data/generated/limits.dart      (field limits as Dart constants, for form checks)

Run with:  python tools/codegen.py   (or `make gen`)
Never edit the generated files by hand; edit the YAML and regenerate.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "models"
ENDPOINTS = MODELS / "endpoints.yml"
DART_OUT = ROOT / "frontend" / "lib" / "data" / "generated"
HEADER = "GENERATED FROM models/ BY tools/codegen.py. DO NOT EDIT BY HAND."

SCALARS = {"string", "integer", "number", "boolean", "datetime"}
MODEL_KEYS = {"model", "description", "create", "fields"}
FIELD_KEYS = {"type", "items", "required", "readonly", "nullable", "values", "default",
              "min_length", "max_length", "minimum", "maximum", "max_items", "description"}
ENDPOINT_KEYS = {"name", "method", "path", "query", "body", "returns", "status", "summary", "mode"}
QUERY_TYPES = {"string", "integer"}


class SpecError(ValueError):
    pass


# ---------------------------------------------------------------- loading + validation

def load_models() -> dict[str, dict]:
    models = {}
    for path in sorted(MODELS.glob("*.yml")):
        if path == ENDPOINTS:
            continue
        spec = yaml.safe_load(path.read_text())
        _check_keys(spec, MODEL_KEYS, path.name)
        models[spec["model"]] = spec
    for name, spec in models.items():
        for fname, f in spec["fields"].items():
            where = f"{name}.{fname}"
            _check_keys(f, FIELD_KEYS, where)
            t = f["type"]
            if t not in SCALARS | {"enum", "array"} and t not in models:
                raise SpecError(f"{where}: unknown type {t!r}")
            if t == "array" and f.get("items", "string") not in SCALARS | set(models):
                raise SpecError(f"{where}: unknown array item type {f['items']!r}")
            if t == "enum" and not f.get("values"):
                raise SpecError(f"{where}: enum needs `values`")
    return dict(_dependency_order(models))


def load_api(models: dict) -> dict:
    api = yaml.safe_load(ENDPOINTS.read_text())
    _check_keys(api, {"base_path", "endpoints", "internal"}, ENDPOINTS.name)
    known = set(models) | {f"{m}Create" for m, s in models.items() if s.get("create")}
    for ep in api["endpoints"] + api.get("internal", []):
        _check_keys(ep, ENDPOINT_KEYS, ep.get("name", "?"))
        for key in ("body", "returns"):
            if key in ep and ep[key] not in known:
                raise SpecError(f"{ep['name']}: unknown {key} type {ep[key]!r}")
        for q, t in ep.get("query", {}).items():
            if t not in QUERY_TYPES:
                raise SpecError(f"{ep['name']}: query param {q!r} has unsupported type {t!r}")
    return api


def _check_keys(d: dict, allowed: set[str], where: str) -> None:
    unknown = set(d) - allowed
    if unknown:
        raise SpecError(f"{where}: unknown keys {sorted(unknown)}")


def _refs(spec: dict) -> set[str]:
    out = set()
    for f in spec["fields"].values():
        out.add(f["type"])
        if f["type"] == "array":
            out.add(f.get("items", "string"))
    return out


def _dependency_order(models: dict) -> list[tuple[str, dict]]:
    """Emit models after the models they contain, so generated code needs no forward references."""
    done: list[str] = []

    def visit(name: str, stack: tuple[str, ...]) -> None:
        if name in done:
            return
        if name in stack:
            raise SpecError(f"circular model reference: {' -> '.join((*stack, name))}")
        for ref in sorted(_refs(models[name]) & set(models)):
            visit(ref, (*stack, name))
        done.append(name)

    for name in models:
        visit(name, ())
    return [(n, models[n]) for n in done]


def create_fields(spec: dict) -> dict:
    """Fields a client sends when creating: everything except readonly ones."""
    return {k: v for k, v in spec["fields"].items() if not v.get("readonly")}


def classes(models: dict) -> list[tuple[str, dict, str]]:
    """(class name, fields, doc) for every generated class, in dependency order."""
    out = []
    for name, spec in models.items():
        out.append((name, spec["fields"], spec.get("description", "")))
        if spec.get("create"):
            out.append((f"{name}Create", create_fields(spec), f"Request body to create a new {name} (server-set fields excluded)."))
    return out


# ---------------------------------------------------------------- JSON Schema

def _type_schema(t: str) -> dict:
    if t == "datetime":
        return {"type": "string", "format": "date-time"}
    if t in SCALARS:
        return {"type": t}
    return {"$ref": f"#/$defs/{t}"}


def field_schema(f: dict) -> dict:
    t = f["type"]
    if t == "enum":
        s: dict = {"type": "string", "enum": f["values"]}
    elif t == "array":
        s = {"type": "array", "items": _type_schema(f.get("items", "string"))}
        if "max_items" in f:
            s["maxItems"] = f["max_items"]
    else:
        s = _type_schema(t)
    for yk, jk in [("min_length", "minLength"), ("max_length", "maxLength"),
                   ("minimum", "minimum"), ("maximum", "maximum"), ("default", "default"),
                   ("description", "description")]:
        if yk in f:
            s[jk] = f[yk]
    if f.get("nullable"):
        s = {"anyOf": [s, {"type": "null"}]}
    if f.get("readonly"):
        s["readOnly"] = True
    return s


def build_schema(models: dict) -> dict:
    defs = {}
    for cls, fields, doc in classes(models):
        is_create = cls.endswith("Create") and cls[:-6] in models
        defs[cls] = {
            "type": "object",
            "description": doc,
            "properties": {k: field_schema(v) for k, v in fields.items()},
            "required": [k for k, v in fields.items() if v.get("required")] if is_create else list(fields),
            "additionalProperties": False,
        }
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$defs": defs}


# ---------------------------------------------------------------- Python (Pydantic)

PY_TYPES = {"string": "str", "integer": "int", "number": "float", "boolean": "bool", "datetime": "datetime"}


def py_type(f: dict) -> str:
    t = f["type"]
    if t == "enum":
        base = "Literal[" + ", ".join(repr(v) for v in f["values"]) + "]"
    elif t == "array":
        item = f.get("items", "string")
        base = f"list[{PY_TYPES.get(item, item)}]"
    else:
        base = PY_TYPES.get(t, t)
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
                   ("minimum", "ge"), ("maximum", "le"), ("max_items", "max_length"),
                   ("description", "description")]:
        if yk in f:
            args.append(f"{pk}={f[yk]!r}")
    return f"    {name}: {py_type(f)} = Field({', '.join(args)})"


def build_python(models: dict) -> str:
    out = [f'"""{HEADER}"""', "", "from __future__ import annotations", "",
           "from datetime import datetime", "from typing import Literal", "",
           "from pydantic import BaseModel, Field", ""]
    for cls, fields, doc in classes(models):
        create = cls.endswith("Create") and cls[:-6] in models
        out += ["", f"class {cls}(BaseModel):", f'    """{doc}"""', ""]
        out += [py_field(k, v, create=create) for k, v in fields.items()]
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def build_python_api(api: dict) -> str:
    return "\n".join([
        f'"""{HEADER}', "",
        "What the backend needs from models/endpoints.yml at run time (models/ is not in the server image).",
        '"""', "", f"BASE_PATH = {api['base_path']!r}", ""])


# ---------------------------------------------------------------- Dart

DART_TYPES = {"string": "String", "integer": "int", "number": "double", "boolean": "bool",
              "datetime": "DateTime", "enum": "String"}


def dart_type(f: dict) -> str:
    t = f["type"]
    if t == "array":
        item = f.get("items", "string")
        base = f"List<{DART_TYPES.get(item, item)}>"
    else:
        base = DART_TYPES.get(t, t)
    return base + "?" if f.get("nullable") else base


def _dart_value_from_json(t: str, j: str) -> str:
    if t == "datetime":
        return f"DateTime.parse({j} as String)"
    if t == "number":
        return f"({j} as num).toDouble()"
    if t in DART_TYPES:
        return f"{j} as {DART_TYPES[t]}"
    return f"{t}.fromJson({j} as Map<String, dynamic>)"


def dart_from_json(name: str, f: dict) -> str:
    j = f"json['{name}']"
    t = f["type"]
    if t == "array":
        item = f.get("items", "string")
        if item in SCALARS and item not in ("datetime", "number"):
            expr = f"(({j} ?? []) as List).cast<{DART_TYPES[item]}>()"
        else:
            expr = f"(({j} ?? []) as List).map((e) => {_dart_value_from_json(item, 'e')}).toList()"
    else:
        expr = _dart_value_from_json(t, j)
    if f.get("nullable"):
        return f"{j} == null ? null : {expr}"
    return expr


def dart_to_json(name: str, f: dict) -> str:
    q = "?" if f.get("nullable") else ""
    t = f["type"]
    if t == "datetime":
        return f"{name}{q}.toIso8601String()"
    if t == "array":
        item = f.get("items", "string")
        if item == "datetime":
            return f"{name}{q}.map((e) => e.toIso8601String()).toList()"
        if item not in SCALARS:
            return f"{name}{q}.map((e) => e.toJson()).toList()"
        return name
    if t not in SCALARS and t != "enum":
        return f"{name}{q}.toJson()"
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


def build_dart_models(models: dict) -> str:
    out = [f"// {HEADER}", "// ignore_for_file: type=lint", ""]
    for cls, fields, doc in classes(models):
        out += dart_class(cls, fields, doc)
    return "\n".join(out)


LIMIT_SUFFIX = {"min_length": "MinLength", "max_length": "MaxLength", "minimum": "Min", "maximum": "Max",
                "max_items": "MaxItems"}


def _dart_limit(f: dict, key: str) -> str:
    v = f[key]
    if key == "minimum" or key == "maximum":
        return repr(float(v)) if f["type"] == "number" else str(int(v))
    return str(int(v))


def build_dart_limits(models: dict) -> str:
    """One `<Model>Limits` class per model with limits, so forms check exactly what the API enforces."""
    out = [f"// {HEADER}", "// ignore_for_file: type=lint", ""]
    for name, spec in models.items():
        consts = [f"  static const {camel(k)}{suffix} = {_dart_limit(f, key)};"
                  for k, f in spec["fields"].items() for key, suffix in LIMIT_SUFFIX.items() if key in f]
        if consts:
            out += [f"/// Field limits of {name} (models/), the same ones the API enforces.",
                    f"abstract final class {name}Limits {{", *consts, "}", ""]
    return "\n".join(out)


def build_dart_client(api: dict, models: dict) -> str:
    has_error = "ErrorResponse" in models
    out = [f"// {HEADER}", "// ignore_for_file: type=lint", "",
           "import 'dart:convert';", "", "import 'package:http/http.dart' as http;", "",
           "import 'models.dart';", "",
           "class ApiException implements Exception {",
           "  final int statusCode;", "  final String body;"]
    if has_error:
        out += ["  /// Parsed error body, when the server sent the standard ErrorResponse shape.",
                "  final ErrorResponse? error;", "  ApiException(this.statusCode, this.body, this.error);"]
    else:
        out += ["  ApiException(this.statusCode, this.body);"]
    out += ["  @override", "  String toString() => 'ApiException($statusCode): $body';", "}", "",
            "class ApiClient {", "  final String baseUrl;", "  final http.Client _http;", "",
            "  ApiClient(String host, {http.Client? client})",
            f"      : baseUrl = '$host{api['base_path']}',",
            "        _http = client ?? http.Client();", "",
            "  dynamic _decode(http.Response r) {",
            "    final text = utf8.decode(r.bodyBytes);",
            "    if (r.statusCode >= 400) {"]
    if has_error:
        out += ["      ErrorResponse? error;",
                "      try {",
                "        error = ErrorResponse.fromJson(jsonDecode(text) as Map<String, dynamic>);",
                "      } catch (_) {}",
                "      throw ApiException(r.statusCode, text, error);"]
    else:
        out += ["      throw ApiException(r.statusCode, text);"]
    out += ["    }", "    return jsonDecode(text);", "  }", ""]
    for ep in api["endpoints"]:
        path = ep["path"]
        params = [seg[1:-1] for seg in path.split("/") if seg.startswith("{")]
        args = [f"String {camel(p)}" for p in params]
        if "body" in ep:
            args.append(f"{ep['body']} body")
        query = ep.get("query", {})
        named = [f"{'int' if t == 'integer' else 'String'}? {camel(q)}" for q, t in query.items()]
        sig = ", ".join(args)
        if named:
            sig += (", " if sig else "") + "{" + ", ".join(named) + "}"
        ret = ep["returns"]
        dart_path = path
        for p in params:
            dart_path = dart_path.replace("{" + p + "}", "$" + camel(p))
        out.append(f"  /// {ep.get('summary', '')}")
        out.append(f"  Future<{ret}> {ep['name']}({sig}) async {{")
        if query:
            values = {q: f"{camel(q)}.toString()" if t == "integer" else camel(q) for q, t in query.items()}
            qmap = ", ".join(f"if ({camel(q)} != null) '{q}': {v}" for q, v in values.items())
            out.append(f"    final uri = Uri.parse('$baseUrl{dart_path}').replace(queryParameters: {{{qmap}}});")
        else:
            out.append(f"    final uri = Uri.parse('$baseUrl{dart_path}');")
        m = ep["method"].lower()
        if "body" in ep:
            out.append(f"    final r = await _http.{m}(uri, headers: {{'Content-Type': 'application/json'}}, "
                       "body: jsonEncode(body.toJson()));")
        else:
            out.append(f"    final r = await _http.{m}(uri);")
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
    try:
        models = load_models()
        api = load_api(models)
    except SpecError as e:
        sys.exit(f"models/ is invalid: {e}")
    print("Generating code from models/ ...")
    write(MODELS / "build" / "schema.json", json.dumps(build_schema(models), indent=2) + "\n")
    write(ROOT / "backend" / "app" / "generated" / "models.py", build_python(models))
    write(ROOT / "backend" / "app" / "generated" / "api.py", build_python_api(api))
    write(ROOT / "backend" / "app" / "generated" / "__init__.py", "")
    write(DART_OUT / "models.dart", build_dart_models(models))
    write(DART_OUT / "api_client.dart", build_dart_client(api, models))
    write(DART_OUT / "limits.dart", build_dart_limits(models))
    print("Done.")


if __name__ == "__main__":
    main()
