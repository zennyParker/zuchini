import hashlib
import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('package_game', Path(__file__).with_name('package-game.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def library():
    name = b'@executable_path/Frameworks/Monite.dylib\0'
    size = (24 + len(name) + 7) & ~7
    header = struct.pack('<8I', 0xfeedfacf, 0x100000c, 0, 6, 1, size, 0, 0)
    return header + struct.pack('<6I', 0xD, size, 24, 0, 0, 0) + name + bytes(size-24-len(name))

class PackageGameTests(unittest.TestCase):
    def test_rejects_bad_library_and_wrong_loader_slot(self):
        for data in [b'', b'bad header'*5, library().replace(b'Monite', b'Otherx')]:
            with self.assertRaises(ValueError): module.verify_library(data)
        module.verify_library(library())

    def test_rejects_existing_output_before_reading_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'existing.ipa'
            path.write_bytes(b'keep')
            with self.assertRaises(ValueError): module.package(Path('missing'), Path('missing'), path)
            self.assertEqual(path.read_bytes(), b'keep')

    def test_preserves_game_payload_and_original_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); game=root/'input.zip'; runtime=root/'runtime.dylib'; output=root/'new.ipa'
            runtime.write_bytes(library())
            info={'CFBundleIdentifier':'com.dts.freefireth','CFBundleShortVersionString':'1.132.1','MinimumOSVersion':'10.0'}
            fixture=module.PREFIX+'fixture.bin'
            with zipfile.ZipFile(game,'w') as archive:
                archive.writestr(fixture,b'unchanged game payload')
                archive.writestr(module.LIBRARY,b'old menu')
                archive.writestr(module.PREFIX+'Info.plist',plistlib.dumps(info))
                archive.writestr(module.PREFIX+'_CodeSignature/CodeResources',b'old signature')
            before=game.read_bytes(); expected=module.EXPECTED
            try:
                module.EXPECTED={fixture:hashlib.sha256(b'unchanged game payload').hexdigest()}
                report=module.package(game,runtime,output)
                with zipfile.ZipFile(output) as archive:
                    self.assertEqual(archive.read(fixture),b'unchanged game payload')
                    self.assertEqual(archive.read(module.LIBRARY),library())
                    self.assertEqual(plistlib.loads(archive.read(module.PREFIX+'Info.plist'))['MinimumOSVersion'],'16.0')
                    self.assertNotIn(module.PREFIX+'_CodeSignature/CodeResources',archive.namelist())
                self.assertEqual(game.read_bytes(),before)
                self.assertFalse(report['device_gameplay_verified'])
            finally: module.EXPECTED=expected

    def test_wrong_game_fingerprint_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            game=Path(directory)/'input.zip'
            with zipfile.ZipFile(game,'w') as archive:
                archive.writestr(module.LIBRARY,b'old')
                for name in module.EXPECTED: archive.writestr(name,b'wrong build')
            with zipfile.ZipFile(game) as archive:
                with self.assertRaises(ValueError): module.verify_input(archive)

if __name__=='__main__': unittest.main()
