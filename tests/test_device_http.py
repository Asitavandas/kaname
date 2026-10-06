import json
import unittest
from unittest.mock import patch

from .test_enrollment_http import EnrollmentHTTPTests


class DeviceHTTPTests(EnrollmentHTTPTests):
    def test_machine_endpoint_never_accepts_browser_token_or_remote_user_headers(self):
        for headers in ({'X-Remote-User':'PC01$@LAB.EXAMPLE'},self.login(),{'Authorization':'Bearer '+self.server.token}):
            status,body,_=self.request('POST','/api/device/issue',{'id':'0'*64,'message':'e30=','mic':'AA=='},headers)
            self.assertEqual(403,status) # browser Origin also explicitly refused
        status,body,_=self.request('POST','/api/device/session',{'token':'TlRMTVNTUA=='})
        self.assertEqual(403,status)
        status,body,_=self.request('POST','/api/device/issue',{'id':'0'*64,'message':'e30=','mic':'AA=='},
            {'Origin':'','X-Remote-User':'PC01$@LAB.EXAMPLE',**self.login()})
        self.assertEqual(403,status);self.assertEqual('DEVICE_SESSION_EXPIRED',body['error'])

    def test_profile_and_signer_admin_require_session_csrf_write_and_https(self):
        self.assertEqual(401,self.request('GET','/api/device-admin/status')[0])
        headers=self.login()
        self.assertEqual(403,self.request('POST','/api/device-admin/profile',{}, {'Cookie':headers['Cookie']})[0])
        self.assertEqual(403,self.request('POST','/api/device-admin/renew-now',{'serial':'1'}, {'Cookie':headers['Cookie']})[0])
        self.assertEqual(403,self.request('POST','/api/pki/archive',{'serial':'1'}, {'Cookie':headers['Cookie']})[0])
        with patch('kaname.server.permits',return_value=False):
            self.assertEqual(403,self.request('GET','/api/device-admin/status',headers=headers)[0])
        with patch.object(self.server,'tls',False):
            status,body,_=self.request('POST','/api/device-admin/unlock',{'ca_password':'fixture-http-enrollment-12345'},headers)
        self.assertEqual('PKI_HTTPS_REQUIRED',body['error'])

    def test_status_distinguishes_absent_keytab_and_disabled_signer(self):
        status,body,_=self.request('GET','/api/device-admin/status',headers=self.login())
        self.assertEqual(200,status);self.assertFalse(body['kerberos_ready']);self.assertFalse(body['signer_enabled'])
        self.assertTrue(body['signing_required']);self.assertFalse(body['radius_changed'])
        self.assertNotIn('PRIVATE KEY',json.dumps(body))
