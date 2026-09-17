from __future__ import annotations

import re
import json
from pathlib import Path
from typing import Any
from urllib import request


ROOT = Path(__file__).resolve().parents[1]
SWAGGER_PATH = "https://api.dandanplay.net/swagger/v2/swagger.json"
OUTPUT_PATH = ROOT / "sources" / "meta" / "dandanplay.lua"


HTTP_METHODS = {"get", "post", "put", "patch", "delete", "head", "options"}
SCHEMAS: dict[str, Any] = {}


def api_name(name: str) -> str:
    return f"DandanAPI{name}"


def ref_name(ref: str) -> str:
    return api_name(ref.rsplit("/", 1)[-1])


def operation_name(operation_id: str) -> str:
    return f"DandanAPI_{operation_id}"


def clean_text(text: Any) -> str:
    if text is None:
        return ""
    return " ".join(str(text).replace("\r\n", "\n").replace("\r", "\n").split())


def comment_block(lines: list[str], out: list[str]) -> None:
    for line in lines:
        if line:
            out.append(f"--- {line}")
        else:
            out.append("---")


def description_lines(description: str) -> list[str]:
    if not description:
        return []

    lines: list[str] = []
    for raw in description.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("### "):
            lines.append(f"### {line[4:].strip()}")
        elif line.startswith("## "):
            lines.append(f"### {line[3:].strip()}")
        else:
            lines.append(line)
    return lines


def literal(value: Any) -> str:
    if isinstance(value, str):
        return f"'{value}'"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "nil"
    return str(value)


def schema_type(schema: dict[str, Any] | None) -> str:
    if not schema:
        return "any"

    if "$ref" in schema:
        return ref_name(schema["$ref"])

    if "oneOf" in schema:
        types = [schema_type(item) for item in schema["oneOf"] if item]
        types = [item for index, item in enumerate(types) if item not in types[:index]]
        return "|".join(types) if types else "any"

    if "allOf" in schema:
        refs = [schema_type(item) for item in schema["allOf"] if "$ref" in item]
        return refs[0] if refs else "table"

    if "enum" in schema:
        return "|".join(literal(item) for item in schema["enum"])

    typ = schema.get("type")
    if typ == "array":
        item_type = schema_type(schema.get("items"))
        if "|" in item_type and not item_type.startswith("("):
            item_type = f"({item_type})"
        return f"{item_type}[]"
    if typ == "integer":
        return "int"
    if typ == "number":
        return "number"
    if typ == "boolean":
        return "boolean"
    if typ == "string":
        return "string"
    if typ == "object":
        if schema.get("additionalProperties"):
            return "table<string, any>"
        return "table"

    return "any"


def is_nullable(schema: dict[str, Any]) -> bool:
    nullable = None
    nullable = schema.get("nullable")
    if nullable is not None:
        return nullable
    for key in ("oneOf", "allOf"):
        for item in schema.get(key, []):
            nullable = is_nullable(item)
            if nullable is not None:
                return nullable
    return False

starting_optional_patt = re.compile(r'^\[可选\]')
def field_description(schema: dict[str, Any]) -> str:
    parts: list[str] = []
    description = clean_text(schema.get("description"))
    if description:
        if starting_optional_patt.match(description):
            description = description[4:] + '[可选]'
        parts.append(description)
    if "default" in schema and '默认为' not in description:
        parts.append(f"(默认: `{literal(schema['default'])}`)")
    return " ".join(parts)


def object_parts(schema: dict[str, Any]) -> tuple[list[str], dict[str, Any]]:
    parents: list[str] = []
    merged: dict[str, Any] = {}

    if "allOf" not in schema:
        return parents, schema

    for item in schema["allOf"]:
        if "$ref" in item:
            parents.append(ref_name(item["$ref"]))
        elif item.get("type") == "object":
            merged.setdefault("properties", {}).update(item.get("properties", {}))
            if "required" in item:
                merged.setdefault("required", []).extend(item["required"])
            if item.get("description") and not merged.get("description"):
                merged["description"] = item["description"]

    return parents, merged


def emit_fields(
    out: list[str],
    properties: dict[str, Any],
    *,
    required: set[str] | None = None,
) -> None:
    required = required or set()
    for name, prop in properties.items():
        suffix = "?" if is_nullable(prop) or (required and name not in required) else ""
        typ = schema_type(prop)
        desc = field_description(prop)
        line = f"---@field {name}{suffix} {typ}"
        if desc:
            line += f" {desc}"
        out.append(line)


def emit_inline_class(
    out: list[str],
    class_name: str,
    schema: dict[str, Any],
) -> None:
    if "$ref" in schema:
        schema = SCHEMAS[schema["$ref"].rsplit("/", 1)[-1]]
    _, body = object_parts(schema)
    out.append(f"---@class {class_name}")
    emit_fields(out, body.get("properties", {}), required=set(body.get("required", [])))


def first_json_schema(content_owner: dict[str, Any]) -> dict[str, Any] | None:
    content = content_owner.get("content", {})
    if not content:
        return None
    media = content.get("application/json") or next(iter(content.values()))
    return media.get("schema")


def emit_operation(
    out: list[str],
    path: str,
    method: str,
    operation: dict[str, Any],
) -> None:
    op_name = operation_name(operation["operationId"])
    summary = operation.get("summary")
    if summary:
        out.append(f"--- ## {summary}")
    out.append(f"--- `{path}`")
    comment_block(description_lines(operation.get("description", "")), out)

    method_literal = method.upper()
    out.append(f"---@param method '{method_literal}'")

    request_parts: list[str] = []
    params = operation.get("parameters", [])
    if params:
        request_parts.append(f"parameters: {op_name}_Parameters")

    body_schema = None
    if "requestBody" in operation:
        body_schema = first_json_schema(operation["requestBody"])
        if body_schema:
            request_parts.append(f"body: {op_name}_Body")

    if request_parts:
        out.append(f"---@param request {{ {', '.join(request_parts)} }}")
        function_args = "method, request"
    else:
        function_args = "method, request"
        out.append("---@param request? table")

    for status, response in operation.get("responses", {}).items():
        response_schema = first_json_schema(response)
        response_type = schema_type(response_schema) if response_schema else "nil"
        out.append(f"---@return {response_type} {status}")

    out.append(f"function M.{op_name}({function_args}) end")

    if params:
        out.append(f"---@class {op_name}_Parameters")
        for param in params:
            prop = dict(param.get("schema") or {})
            if param.get("description") and not prop.get("description"):
                prop["description"] = param["description"]
            if param.get("required") is False:
                prop["nullable"] = True
            default = prop.get('default')
            suffix = "?" if is_nullable(prop) or default is not None else ""
            typ = schema_type(prop)
            desc = field_description(prop)
            line = f"---@field {param['name']}{suffix} {typ}"
            if desc:
                line += f" {desc}"
            out.append(line)

    if body_schema:
        emit_inline_class(out, f"{op_name}_Body", body_schema)


def emit_schema(out: list[str], name: str, schema: dict[str, Any]) -> None:
    class_name = api_name(name)

    if "enum" in schema:
        out.append(f"---@alias {class_name}")
        for item in schema["enum"]:
            out.append(f"--- | {literal(item)}")
        return

    parents, body = object_parts(schema)
    parent_part = f" : {', '.join(parents)}" if parents else ""
    out.append(f"---@class {class_name}{parent_part}")
    emit_fields(out, body.get("properties", {}), required=set(body.get("required", [])))


def generate(swagger: dict[str, Any]) -> str:
    out: list[str] = [
        "---@meta",
        "-- Generated from dandanplay_swagger.json by tools/gen.py",
        "",
        "---@class DandanAPI",
        "local M = {}",
        "",
        "-- ===========================================================",
        "-- PATHS",
        "-- ===========================================================",
        "",
    ]

    for path, item in swagger["paths"].items():
        for method, operation in item.items():
            if method not in HTTP_METHODS:
                continue
            emit_operation(out, path, method, operation)
            out.append("")

    out.extend(
        [
            "-- ===========================================================",
            "-- COMPONENTS",
            "-- ===========================================================",
        ]
    )

    for name, schema in swagger["components"]["schemas"].items():
        out.append("")
        emit_schema(out, name, schema)

    out.extend(["", "return M", ""])
    return "\n".join(out)


if __name__ == "__main__":
    with request.urlopen(SWAGGER_PATH) as resp:
        swagger = json.loads(resp.read().decode('utf-8'))

    SCHEMAS = swagger["components"]["schemas"]
    OUTPUT_PATH.write_text(generate(swagger), encoding="utf-8", newline="\n")
