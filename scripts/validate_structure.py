"""Validate generated project structure with Python's standard library.

This does not type-check Swift or replace xcodebuild / swift test.
"""
import json
import re
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
project = ROOT / "Examples/ZuchiniDemo/ZuchiniDemo.xcodeproj"
text = (project / "project.pbxproj").read_text(encoding="utf-8")
text = re.sub(r"//[^\n]*", "", text)
tokenizer = re.compile(r'\s*("(?:\\.|[^"\\])*"|[{}()=;,])')
tokens = []
cursor = 0
while cursor < len(text):
    if not text[cursor:].strip(): break
    match = tokenizer.match(text, cursor)
    if not match: raise ValueError(f"Unexpected project syntax at offset {cursor}")
    tokens.append(match.group(1))
    cursor = match.end()
position = 0

def take(expected=None):
    global position
    token = tokens[position]
    position += 1
    if expected is not None and token != expected:
        raise ValueError(f"Expected {expected}, got {token}")
    return token

def parse():
    token = take()
    if token == "{":
        result = {}
        while tokens[position] != "}":
            key = json.loads(take())
            if key in result: raise ValueError(f"Duplicate property {key}")
            take("=")
            result[key] = parse()
            take(";")
        take("}")
        return result
    if token == "(":
        result = []
        while tokens[position] != ")":
            result.append(parse())
            take(",")
        take(")")
        return result
    return json.loads(token)

document = parse()
assert position == len(tokens)
objects = document["objects"]
assert objects[document["rootObject"]]["isa"] == "PBXProject"

def verify_references(value):
    if isinstance(value, dict):
        for nested in value.values(): verify_references(nested)
    elif isinstance(value, list):
        for nested in value: verify_references(nested)
    elif isinstance(value, str) and re.fullmatch(r"[A-F0-9]{24}", value):
        assert value in objects, f"Dangling Xcode object: {value}"

verify_references(objects)
source_refs = [v for v in objects.values() if v["isa"] == "PBXFileReference" and v.get("lastKnownFileType") == "sourcecode.swift"]
for ref in source_refs:
    assert (project.parent / ref["path"]).is_file(), ref
local = next(v for v in objects.values() if v["isa"] == "XCLocalSwiftPackageReference")
assert (project.parent / local["relativePath"]).resolve() == ROOT
assert (ROOT / "Package.swift").is_file()
for target in ["ZuchiniCore", "ZuchiniMenu"]:
    assert list((ROOT / "Sources" / target).glob("*.swift"))
scheme = ET.parse(project / "xcshareddata/xcschemes/ZuchiniDemo.xcscheme")
references = scheme.findall(".//BuildableReference")
assert len(references) == 4
for ref in references:
    assert objects[ref.attrib["BlueprintIdentifier"]]["isa"] == "PBXNativeTarget"
    target = objects[ref.attrib["BlueprintIdentifier"]]
    assert ref.attrib["BuildableName"] == objects[target["productReference"]]["path"]
assert list((ROOT / "Tests/ZuchiniCoreTests").glob("*.swift"))
print(json.dumps({"project_objects": len(objects), "source_file_references": len(source_refs), "scheme_references": len(references), "local_package_path_valid": True, "swift_compilation_performed": False}, indent=2))
