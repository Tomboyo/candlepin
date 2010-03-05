import unittest
import httplib, urllib
import simplejson as json
import base64
import os

from urllib import urlopen
from candlepinapi import Rest
from certs import SPACEWALK_PUBLIC_CERT
from candlepinapi import Rest, CandlePinApi

CERTS_UPLOADED = False

class CandlepinTests(unittest.TestCase):

    def setUp(self):

        self.cp = CandlePinApi(hostname="localhost", port="8080", api_url="/candlepin")

        # TODO: Use CandlePinAPI?
        # Upload the test cert to populate Candlepin db. Only do this
        # once per test suite run.
        rest = Rest(hostname="localhost", port="8080", api_url="/candlepin")
        #rest = Rest(hostname="localhost", port="8443", api_url="/candlepin", cert_file="./cert_chain.crt", key_file="./cert_chain_private_pem.key")
        rsp = rest.get("/certificates")
        if not rsp:
            print("Cert upload required.")

            cert = self.__read_cert()
            encoded_cert = base64.b64encode(cert)
            params = {"base64cert": encoded_cert}
            headers = {"Content-type": "application/json",
                    "Accept": "application/json"}

            rest.post("/certificates", json.dumps(encoded_cert))

            rsp = rest.get("/certificates")
            self.assertTrue(rsp.strip() != "")

        self.uuid = self.create_consumer()

    def assertResponse(self, expected_status, response):
        if response.status != expected_status:
            self.fail("Status: %s Reason: %s" % (response.status, response.reason))

    def __read_cert(self, cert_file='code/scripts/spacewalk-public.cert'):
        cert_file = os.path.abspath(os.path.join(__file__, '../..', cert_file))
        return open(cert_file, 'rb').read()

    def create_consumer(self):
        facts_metadata = {
                "a": "1",
                "b": "2",
                "c": "3"}
        response = self.cp.registerConsumer("fakeuser", "fakepw",
                "consumername", hardware=facts_metadata)
        return response['uuid']


## GET see if there's a certificate
#response = urllib.urlopen('http://localhost:8080/candlepin/certificate')
#rsp = response.read()
#print("get: %s" % rsp)

##"""
## POST upload a certificate
#print("upload certificate")


