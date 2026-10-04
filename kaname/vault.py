"""Local encrypted secrets. No plaintext secrets in config, responses or audit."""
import ctypes
import json
import os
import secrets
import threading
from pathlib import Path

_KEY_LOCK = threading.Lock()


class VaultError(ValueError):
    pass


class Vault:
    def __init__(self, root):
        self.root = Path(root)

    def _key(self):
        path = self.root / 'secret-store.key'
        with _KEY_LOCK:
            if path.is_symlink():
                raise VaultError('SECRET_STORE_UNAVAILABLE')
            if not path.exists():
                fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
                with os.fdopen(fd, 'wb') as output:
                    output.write(secrets.token_bytes(32))
            if path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o077:
                raise VaultError('SECRET_STORE_UNAVAILABLE')
            value = path.read_bytes()
            if len(value) != 32:
                raise VaultError('SECRET_STORE_UNAVAILABLE')
            return value

    @staticmethod
    def _dpapi(data, purpose, decrypt=False):
        from ctypes import wintypes

        class Blob(ctypes.Structure):
            _fields_ = [('length', wintypes.DWORD), ('data', ctypes.POINTER(ctypes.c_ubyte))]

        source_buf = ctypes.create_string_buffer(data)
        entropy_buf = ctypes.create_string_buffer(('KANAME:' + purpose).encode())
        source = Blob(len(data), ctypes.cast(source_buf, ctypes.POINTER(ctypes.c_ubyte)))
        entropy = Blob(len(entropy_buf.raw) - 1, ctypes.cast(entropy_buf, ctypes.POINTER(ctypes.c_ubyte)))
        target = Blob()
        crypt = ctypes.WinDLL('crypt32', use_last_error=True)
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        function = crypt.CryptUnprotectData if decrypt else crypt.CryptProtectData
        function.argtypes = [ctypes.POINTER(Blob), ctypes.c_void_p, ctypes.POINTER(Blob), ctypes.c_void_p,
                             ctypes.c_void_p, wintypes.DWORD, ctypes.POINTER(Blob)]
        function.restype = wintypes.BOOL
        kernel.LocalFree.argtypes = [ctypes.c_void_p]
        kernel.LocalFree.restype = ctypes.c_void_p
        # USER scope; UI forbidden; never use CRYPTPROTECT_LOCAL_MACHINE.
        if not function(ctypes.byref(source), None, ctypes.byref(entropy), None, None, 1, ctypes.byref(target)):
            raise VaultError('SECRET_STORE_UNAVAILABLE')
        try:
            return ctypes.string_at(target.data, target.length)
        finally:
            ctypes.memset(target.data, 0, target.length)
            kernel.LocalFree(target.data)

    def seal(self, purpose, value):
        try:
            data = json.dumps({'purpose': purpose, 'value': value}, ensure_ascii=False).encode()
            if os.name == 'nt':
                return b'DP1' + self._dpapi(data, purpose)
            from cryptography.hazmat.primitives.ciphers.aead import AESGCM
            nonce = secrets.token_bytes(12)
            return b'AG1' + nonce + AESGCM(self._key()).encrypt(nonce, data, purpose.encode())
        except (OSError, ValueError, ImportError):
            raise VaultError('SECRET_STORE_UNAVAILABLE') from None

    def open(self, purpose, value):
        try:
            if os.name == 'nt' and value.startswith(b'DP1'):
                data = self._dpapi(value[3:], purpose, True)
            elif os.name != 'nt' and value.startswith(b'AG1'):
                from cryptography.hazmat.primitives.ciphers.aead import AESGCM
                data = AESGCM(self._key()).decrypt(value[3:15], value[15:], purpose.encode())
            else:
                raise ValueError()
            result = json.loads(data)
            if result['purpose'] != purpose or type(result['value']) is not str:
                raise ValueError()
            return result['value']
        except Exception:
            raise VaultError('SECRET_STORE_UNAVAILABLE') from None
