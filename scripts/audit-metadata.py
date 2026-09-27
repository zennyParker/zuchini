"""Reproducible, read-only audit of this supplied IL2CPP metadata variant.
Writes a separate parser-compatible analysis copy; never patches the game input.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

EXPECTED = '597e77fc1dd15bac9ff75215bd328d60c6d205f5fc4a7e32cec1b37d3cc2ea5d'

def audit(source, destination):
    original = source.read_bytes()
    if hashlib.sha256(original).hexdigest() != EXPECTED:
        raise ValueError('This transformation is specific to the inspected 1.132.1 metadata')
    if destination.exists() or source.resolve() == destination.resolve():
        raise ValueError('Analysis output must be a new file')
    read = lambda offset: struct.unpack_from('<I', original, offset)[0]
    if (read(0), read(4)) != (0xfab11baf, 31):
        raise ValueError('Unsupported metadata header')
    strings, string_size = read(24), read(28)
    methods, method_size = read(48), read(52)
    generics, generic_size = read(120), read(124)
    type_size = read(164)
    if method_size % 40 or type_size % 88 or generic_size % 16:
        raise ValueError('Table lengths do not match the inspected variant')
    count = method_size // 40
    for index in range(count):
        offset = methods + index * 40
        name = read(offset)
        if not (name < string_size and (name == 0 or original[strings + name - 1] == 0)):
            raise ValueError(f'Invalid method name index at {index}')
        if read(offset + 4) >= type_size // 88 or read(offset + 28) >> 24 != 6:
            raise ValueError(f'Invalid method owner/token at {index}')
    generic_links = 0
    for index in range(generic_size // 16):
        owner, _, is_method, _ = struct.unpack_from('<iiii', original, generics + index * 16)
        if is_method:
            if not 0 <= owner < count or read(methods + owner * 40 + 20) != index:
                raise ValueError('Generic container field alignment is inconsistent')
            generic_links += 1
    compact = b''.join(original[p:p+24] + original[p+28:p+40] for p in range(methods, methods+method_size, 40))
    result = bytearray(original[:methods] + compact + original[methods+method_size:])
    removed = count * 4
    for offset in range(8, 256, 8):
        position, size = struct.unpack_from('<II', original, offset)
        if position + size > len(original):
            raise ValueError('Header section lies outside the input')
        if position >= methods + method_size:
            struct.pack_into('<I', result, offset, position - removed)
        elif position > methods:
            raise ValueError('Unexpected section overlap')
    struct.pack_into('<I', result, 52, count * 36)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open('xb') as out:
        out.write(result)
    return {'original_sha256': EXPECTED, 'declared_version': 31,
            'observed_method_stride': 40, 'normalized_method_stride': 36,
            'validated_methods': count, 'validated_method_generic_links': generic_links,
            'types': type_size // 88, 'extra_word_semantics': 'unknown',
            'analysis_sha256': hashlib.sha256(result).hexdigest(), 'original_modified': False}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    print(json.dumps(audit(args.source, args.destination), indent=2))
