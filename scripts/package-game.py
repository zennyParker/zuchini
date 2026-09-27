"""Package the exact supplied game with our own library. Never edits the input archive.

The output is unsigned and requires full ESign re-signing. No game data is uploaded.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import struct
import zipfile

PREFIX = 'Payload/FreeFire.app/'
LIBRARY = PREFIX + 'Frameworks/Monite.dylib'
UNITY = PREFIX + 'Frameworks/UnityFramework.framework/UnityFramework'
EXPECTED = {
    PREFIX + 'FreeFire': 'aa6b7e5bf7b664f3a83436e7387ba2fa65931cd91d442aed54fdc787a52386a1',
    UNITY: '024cee6f2ceab308633e9e7568500c67fd49830a0fd32d76dc47e29c7d407cc2',
    PREFIX + 'Data/Managed/Metadata/global-metadata.dat': '597e77fc1dd15bac9ff75215bd328d60c6d205f5fc4a7e32cec1b37d3cc2ea5d',
}

def verify_input(archive):
    names = archive.namelist()
    if len(names) != len(set(names)):
        raise ValueError('Duplicate ZIP paths are ambiguous')
    if LIBRARY not in names:
        raise ValueError('Expected menu load slot is missing')
    for name, digest in EXPECTED.items():
        with archive.open(name) as stream:
            actual = hashlib.file_digest(stream, 'sha256').hexdigest()
        if actual != digest:
            raise ValueError(f'Unsupported game binary: {name}')
    info = plistlib.loads(archive.read(PREFIX + 'Info.plist'))
    if info.get('CFBundleIdentifier') != 'com.dts.freefireth' or info.get('CFBundleShortVersionString') != '1.132.1':
        raise ValueError('Unexpected application identity')
    return info

def verify_library(data):
    if len(data) < 32:
        raise ValueError('Library is truncated')
    magic, cpu, _, kind, count, command_size = struct.unpack_from('<6I', data)
    if (magic, cpu, kind) != (0xfeedfacf, 0x100000c, 6):
        raise ValueError('Expected an arm64 Mach-O dynamic library')
    if count > 1024 or 32 + command_size > len(data):
        raise ValueError('Invalid load commands')
    position = 32
    install_name = None
    for _ in range(count):
        command, size = struct.unpack_from('<II', data, position)
        if size < 8 or position + size > 32 + command_size:
            raise ValueError('Invalid load command size')
        if command == 0xD:
            offset = struct.unpack_from('<I', data, position + 8)[0]
            if not 24 <= offset < size:
                raise ValueError('Invalid install-name offset')
            install_name = data[position+offset:position+size].split(b'\0', 1)[0].decode()
        position += size
    if install_name != '@executable_path/Frameworks/Monite.dylib':
        raise ValueError('Library install name does not match the existing loader slot')

def package(game, library, output):
    if output.exists() or game.resolve() == output.resolve():
        raise ValueError('Choose a new output path; originals and existing builds are never overwritten')
    data = library.read_bytes()
    verify_library(data)
    with zipfile.ZipFile(game) as original:
        info = verify_input(original)
        info['MinimumOSVersion'] = '16.0'
        info['UIFileSharingEnabled'] = True
        info['LSSupportsOpeningDocumentsInPlace'] = True
        output.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive create prevents accidental replacement even if a concurrent process creates it.
        with output.open('xb') as destination, zipfile.ZipFile(destination, 'w', allowZip64=True) as result:
            for item in original.infolist():
                if '/_CodeSignature/' in item.filename or item.filename.endswith('/embedded.mobileprovision'):
                    continue
                entry = copy.copy(item)
                if item.filename == LIBRARY:
                    result.writestr(entry, data)
                elif item.filename == PREFIX + 'Info.plist':
                    result.writestr(entry, plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
                else:
                    with original.open(item) as source, result.open(entry, 'w', force_zip64=True) as target:
                        shutil.copyfileobj(source, target, 1024 * 1024)
    with zipfile.ZipFile(output) as archive:
        bad = archive.testzip()
        if bad:
            raise ValueError(f'Output ZIP integrity failure: {bad}')
        verify_input(archive)
        if hashlib.sha256(archive.read(LIBRARY)).digest() != hashlib.sha256(data).digest():
            raise ValueError('Packaged runtime differs from the build artifact')
    return {'output': str(output.resolve()), 'bytes': output.stat().st_size,
            'sha256': hashlib.file_digest(output.open('rb'), 'sha256').hexdigest(),
            'runtime_sha256': hashlib.sha256(data).hexdigest(),
            'game_binaries_preserved': True, 'minimum_ios': '16.0',
            'signed_for_device': False, 'device_gameplay_verified': False}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--library', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = package(args.game, args.library, args.output)
    args.output.with_suffix('.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))
