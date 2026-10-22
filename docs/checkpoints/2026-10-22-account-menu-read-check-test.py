"""Pre-update checks use old routes; post-update checks require the new route."""
from pathlib import Path
import runpy
import unittest
from unittest.mock import patch

script=Path(__file__).with_name('authwire-account-menu-20261022.py')
if not script.exists():script=Path(__file__).with_name('2026-10-22-account-menu-update.py')
namespace=runpy.run_path(str(script))
measure=namespace['measure']


class ReadCheckTests(unittest.TestCase):
    def check(self, phase, labels_status):
        requests=[]
        class Token:
            def read_text(self):return 'disposable-fixture-token'
        class State:
            def __truediv__(self, name):
                assert name=='access-token'
                return Token()
        class Connection:
            def __init__(self,*args,**kwargs):pass
            def request(self,method,path,headers):
                assert method=='GET'
                self.path=path
                requests.append(path)
            def getresponse(self):
                class Response:
                    status=labels_status if self.path=='/api/system/power' else 200
                    def read(self):return b'{}'
                return Response()
            def close(self):pass
        g=measure.__globals__
        with patch.dict(g,STATE=State(),emit=lambda *args,**kwargs:None), \
             patch.object(g['ssl'],'create_default_context',return_value=object()), \
             patch.object(g['http'].client,'HTTPSConnection',Connection):
            measure(phase)
        return requests

    def test_dev17_precheck_does_not_call_new_route(self):
        paths=self.check('before',404)
        self.assertNotIn('/api/system/power',paths)
        self.assertEqual(len(paths),15)

    def test_dev18_postcheck_requires_new_route(self):
        paths=self.check('after',200)
        self.assertEqual(paths.count('/api/system/power'),3)
        self.assertEqual(len(paths),30)

    def test_missing_postupdate_route_fails(self):
        with self.assertRaisesRegex(ValueError,'Panel read check failed'):
            self.check('after',404)


if __name__=='__main__':unittest.main()
