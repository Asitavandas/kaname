from unittest.mock import patch
from .test_enrollment_http import EnrollmentHTTPTests
from .test_radius_live import GROUP


class UserPackageHTTPTests(EnrollmentHTTPTests):
    def test_user_package_requires_authenticated_write_permission_and_https(self):
        path='/api/user-admin/package?profile_id=00000000-0000-4000-8000-000000000001'
        self.assertEqual(401,self.request('GET',path)[0]);headers=self.login()
        with patch('kaname.server.permits',side_effect=lambda actor,resource,write=False:not write):
            self.assertEqual(403,self.request('GET',path,headers=headers)[0])
        with patch.object(self.server,'tls',False):
            self.assertEqual(400,self.request('GET',path,headers=headers)[0])
    def test_user_profile_package_route_cannot_download_computer_package_or_arbitrary_path(self):
        headers=self.login()
        for suffix in ('?profile_id=../../etc/passwd','?profile_id=missing&extra=1','?profile_id=one&profile_id=two'):
            status,body,_=self.request('GET','/api/user-admin/package'+suffix,headers=headers)
            self.assertEqual(400,status)
