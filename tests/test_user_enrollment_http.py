from unittest.mock import patch
from .test_enrollment_http import EnrollmentHTTPTests


class UserEnrollmentHTTPTests(EnrollmentHTTPTests):
    def test_user_endpoint_never_accepts_panel_cookie_token_or_remote_user(self):
        for headers in ({'X-Remote-User':'Alice@LAB.EXAMPLE'},self.login(),{'Authorization':'Bearer '+self.server.token}):
            self.assertEqual(403,self.request('POST','/api/user/issue',{'id':'0'*64,'message':'e30=','mic':'AA=='},headers)[0])
        self.assertEqual(403,self.request('POST','/api/user/session',{'token':'TlRMTVNTUA=='})[0])
        status,body,_=self.request('POST','/api/user/issue',{'id':'0'*64,'message':'e30=','mic':'AA=='},{'Origin':''})
        self.assertEqual((403,'DEVICE_SESSION_EXPIRED'),(status,body['error']))
        self.assertIsNot(self.server.device_sessions,self.server.user_sessions)

    def test_user_admin_status_and_writes_require_permissions_csrf_https(self):
        self.assertEqual(401,self.request('GET','/api/user-admin/status')[0])
        headers=self.login()
        self.assertEqual(403,self.request('POST','/api/user-admin/profile',{}, {'Cookie':headers['Cookie']})[0])
        self.assertEqual(403,self.request('POST','/api/user-admin/renew-now',{'serial':'1'}, {'Cookie':headers['Cookie']})[0])
        with patch('kaname.server.permits',return_value=False):
            self.assertEqual(403,self.request('GET','/api/user-admin/status',headers=headers)[0])
        with patch.object(self.server,'tls',False):
            status,body,_=self.request('POST','/api/user-admin/profile',{},headers)
        self.assertEqual('PKI_HTTPS_REQUIRED',body['error'])
        status,body,_=self.request('GET','/api/user-admin/status',headers=headers)
        self.assertEqual(200,status);self.assertEqual([],body['profiles']);self.assertFalse(body['windows_client_available'])
        self.assertEqual(400,self.request('GET','/api/user-admin/status?offset=0&offset=1',headers=headers)[0])
