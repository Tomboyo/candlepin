#! /usr/bin/env ruby
require 'net/http'
require 'webrick'
require 'webrick/https'

require 'rspec/autorun'
require '../candlepin'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec::Matchers.define :be_2xx do |expected|
  match do |res|
    (200..206).include?(res.status_code)
  end
end

RSpec::Matchers.define :be_unauthorized do |expected|
  match do |res|
    res.status_code == 401
  end
end

RSpec::Matchers.define :be_forbidden do |expected|
  match do |res|
    res.status_code == 403
  end
end

module Candlepin
  describe "Candlepin" do
    def rand_string(len = 9)
      o = [('a'..'z'), ('A'..'Z'), ('1'..'9')].map { |range| range.to_a }.flatten
      (0...len).map { o[rand(o.length)] }.join
    end

    context "in a functional context", :functional => true do
      let!(:user_client) { BasicAuthClient.new }
      let!(:no_auth_client) { NoAuthClient.new }

      it 'gets a status as JSON' do
        res = no_auth_client.get('/status')
        expect(res.content.key?('version')).to be_true
      end

      it 'gets owners with basic auth' do
        res = user_client.get_owners
        expect(res.content.empty?).to be_false
        expect(res.content.first.key?('id')).to be_true
      end

      it 'fails with bad password' do
        res = no_auth_client.get('/owners')
        expect(res).to be_unauthorized
      end

      it 'registers a consumer' do
        res = user_client.register(
          :owner => 'admin',
          :username => 'admin',
          :name => rand_string,
        )
        expect(res).to be_2xx
        expect(res.content['uuid'].length).to eq(36)
      end

      it 'gets deleted consumers' do
        res = user_client.get_deleted_consumers
        expect(res).to be_2xx
      end

      it 'updates a consumer' do
        res = user_client.register(
          :owner => 'admin',
          :username => 'admin',
          :name => rand_string,
        )
        consumer = res.content

        res = user_client.update_consumer(
          :autoheal => false,
          :uuid => consumer['uuid'],
          :capabilities => ['cores'],
        )
        expect(res).to be_2xx
      end

      it 'updates a consumer guest id list' do
        res = user_client.register(
          :owner => 'admin',
          :username => 'admin',
          :name => rand_string,
        )
        consumer = res.content
        user_client.uuid = consumer['uuid']

        res = user_client.update_all_guest_ids(
          :guest_ids => ['123', '456'],
        )
        expect(res).to be_2xx
      end

      it 'deletes a guest id' do
        res = user_client.register(
          :owner => 'admin',
          :username => 'admin',
          :name => rand_string,
        )
        consumer = res.content
        user_client.uuid = consumer['uuid']

        user_client.update_consumer(
          :guest_ids => ['x', 'y', 'z'],
        )
        expect(res).to be_2xx

        res = user_client.delete_guest_id(
          :guest_id => 'x',
        )
        expect(res).to be_2xx
      end

    end

    context "in a unit test context", :unit => true do
      TEST_PORT = 11999
      CLIENT_CERT_TEST_PORT = TEST_PORT + 1
      attr_accessor :server
      attr_accessor :client_cert_server

      before(:all) do
        util_test_class = Class.new(Object) do
          include Util
        end
        Candlepin.const_set("UtilTest", util_test_class)
      end

      before(:each) do
        key = OpenSSL::PKey::RSA.new(File.read('certs/test-ca.key'))
        cert = OpenSSL::X509::Certificate.new(File.read('certs/test-ca.cert'))

        server_config = {
          :BindAddress => 'localhost',
          :Port => TEST_PORT,
          :SSLEnable => true,
          :SSLPrivateKey => key,
          :SSLCertificate => cert,
          :Logger => WEBrick::BasicLog.new(nil, WEBrick::BasicLog::FATAL),
          :AccessLog => [],
        }

        @server = WEBrick::HTTPServer.new(server_config)
        @client_cert_server = WEBrick::HTTPServer.new(server_config.merge({
          :SSLVerifyClient => OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT,
          :SSLCACertificateFile => 'certs/test-ca.cert',
          :Port => CLIENT_CERT_TEST_PORT,
        }))

        [server, client_cert_server].each do |s|
          s.mount_proc('/candlepin/status') do |req, res|
            res.body = '{ "message": "Hello" }'
            res['Content-Type'] = 'text/json'
          end
        end

        @server_thread = Thread.new do
          server.start
        end

        @client_cert_server_thread = Thread.new do
          client_cert_server.start
        end
      end

      after(:each) do
        server.shutdown
        client_cert_server.shutdown
        @server_thread.kill unless @server_thread.nil?
        @client_cert_server_thread.kill unless @client_cert_server_thread.nil?
      end

      it 'uses CA if given' do
        simple_client = NoAuthClient.new(
          :ca_path => 'certs/test-ca.cert',
          :port => TEST_PORT,
          :insecure => false)

        res = simple_client.get('/status')
        expect(res.content['message']).to eq("Hello")
      end

      it 'fails to connect if no CA given in strict mode' do
        simple_client = NoAuthClient.new(
          :port => TEST_PORT,
          :insecure => false)

        expect do
          simple_client.get('/status')
        end.to raise_error(OpenSSL::SSL::SSLError)
      end

      it 'allows a connection with a valid client cert' do
        client_cert = OpenSSL::X509::Certificate.new(File.read('certs/client.cert'))
        client_key = OpenSSL::PKey::RSA.new(File.read('certs/client.key'))
        cert_client = X509Client.new(
          :port => CLIENT_CERT_TEST_PORT,
          :ca_path => 'certs/test-ca.cert',
          :insecure => false,
          :client_cert => client_cert,
          :client_key => client_key)

        res = cert_client.get('/status')
        expect(res.content['message']).to eq("Hello")
      end

      it 'forbids a connection with an invalid client cert' do
        client_cert = OpenSSL::X509::Certificate.new(File.read('certs/unsigned.cert'))
        client_key = OpenSSL::PKey::RSA.new(File.read('certs/unsigned.key'))
        cert_client = X509Client.new(
          :port => CLIENT_CERT_TEST_PORT,
          :ca_path => 'certs/test-ca.cert',
          :insecure => false,
          :client_cert => client_cert,
          :client_key => client_key)

        expect do
          cert_client.get('/status')
        end.to raise_error(OpenSSL::SSL::SSLError, /unknown ca/)
      end

      it 'builds a correct base url' do
        simple_client = NoAuthClient.new(
          :host => "www.example.com",
          :port => 8443,
          :context => "/some_path",
        )
        expect(simple_client.base_url).to eq("https://www.example.com:8443/some_path")
      end

      it 'handles a context with no leading slash' do
        simple_client = NoAuthClient.new(
          :host => "www.example.com",
          :port => 8443,
          :context => "no_slash_path",
        )
        expect(simple_client.base_url).to eq("https://www.example.com:8443/no_slash_path")
      end

      it 'reloads underlying client when necessary' do
        simple_client = NoAuthClient.new(
          :host => "www.example.com",
          :port => 8443,
          :context => "/1",
        )
        url1 = "https://www.example.com:8443/1"
        expect(simple_client.base_url).to eq(url1)
        expect(simple_client.raw_client.base_url).to eq(url1)
        expect(simple_client.raw_client).to be_kind_of(HTTPClient)

        simple_client.context = "/2"
        simple_client.reload

        url2 = "https://www.example.com:8443/2"
        expect(simple_client.base_url).to eq(url2)
        expect(simple_client.raw_client.base_url).to eq(url2)
      end

      it 'builds a client from consumer json' do
        # Note that the consumer.json file has had the signed client.cert and
        # client.key contents inserted into it.
        cert_client = X509Client.from_consumer(
          JSON.load(File.read('json/consumer.json')),
          :port => CLIENT_CERT_TEST_PORT,
          :ca_path => 'certs/test-ca.cert',
          :insecure => false)

        res = cert_client.get('/status')
        expect(res.content['message']).to eq("Hello")
      end

      it 'fails to build client when given both consumer and cert info' do
        client_cert = OpenSSL::X509::Certificate.new(File.read('certs/unsigned.cert'))
        client_key = OpenSSL::PKey::RSA.new(File.read('certs/unsigned.key'))
        expect do
          X509Client.from_consumer(
            JSON.load(File.read('json/consumer.json')),
            :port => CLIENT_CERT_TEST_PORT,
            :ca_path => 'certs/test-ca.cert',
            :client_cert => client_cert,
            :client_key => client_key,
            :insecure => false)
        end.to raise_error(ArgumentError)
      end

      it 'builds a client from cert and key files' do
        cert_client = X509Client.from_files(
          'certs/client.cert',
          'certs/client.key',
          :port => CLIENT_CERT_TEST_PORT,
          :ca_path => 'certs/test-ca.cert',
          :insecure => false)

        res = cert_client.get('/status')
        expect(res.content['message']).to eq("Hello")
      end

      it 'fails to build client when given both consumer and cert files' do
        client_cert = OpenSSL::X509::Certificate.new(File.read('certs/unsigned.cert'))
        client_key = OpenSSL::PKey::RSA.new(File.read('certs/unsigned.key'))
        expect do
          X509Client.from_files(
            'certs/client.cert',
            'certs/client.key',
            :port => CLIENT_CERT_TEST_PORT,
            :ca_path => 'certs/test-ca.cert',
            :client_cert => client_cert,
            :client_key => client_key,
            :insecure => false)
        end.to raise_error(ArgumentError)
      end

      it 'builds query hash properly' do
        params = {
          :colors => %w(red white blue),
          :nothing => nil,
          :k => {
            :k2 => 'v'
          }
        }
        expected = "colors=red&colors=white&colors=blue&k#{CGI.escape('[')}k2#{CGI.escape(']')}=v"
        expect(params.to_query).to eq(expected)
      end

      it 'builds query array properly' do
        params = %w(red white blue)
        expected = "colors=red&colors=white&colors=blue"
        expect(params.to_query('colors')).to eq(expected)

        params = []
        expected = 'colors='
        expect(params.to_query('colors')).to eq(expected)
      end

      it 'builds query objects properly' do
        params = "red"
        expected = "colors=red"
        expect(params.to_query('colors')).to eq(expected)

        params = true
        expected = 'colors=true'
        expect(params.to_query('colors')).to eq(expected)

        params = nil
        expected = 'colors='
        expect(params.to_query('colors')).to eq(expected)
      end

      it 'can select a subset of a hash' do
        original = {
          :x => 1,
          :y => nil,
          :z => 3,
        }
        expected_keys = [:x, :y]
        selected = UtilTest.new.select_from(original, :x, :y)
        expect(selected.keys).to match_array(expected_keys)
      end

      it 'raises an error if not a proper subset' do
        original = {
          :x => 1,
        }
        expect do
          UtilTest.new.select_from(original, :x, :y)
        end.to raise_error(ArgumentError, /Missing keys.*:y/)
      end

      it 'raises an exception on invalid option keys' do
        valid_keys = [:good, :bad, :ugly]
        hash = {
          :good => 'Clint Eastwood',
          :bad => 'Lee Van Cleef',
          :weird => 'Steve Buscemi',
        }
        msg_regex = /contains invalid keys:.*weird/

        expect do
          UtilTest.new.verify_keys(hash, *valid_keys)
        end.to raise_error(RuntimeError, msg_regex)

        expect do
          UtilTest.new.verify_keys(hash, valid_keys)
        end.to raise_error(RuntimeError, msg_regex)
      end

      it 'verifies valid keys' do
        valid_keys = [:good, :bad, :ugly]
        hash = {
          :good => 'Clint Eastwood',
          :bad => 'Lee Van Cleef',
        }
        expect do
          UtilTest.new.verify_keys(hash, *valid_keys)
        end.not_to raise_error

        expect do
          UtilTest.new.verify_keys(hash, valid_keys)
        end.not_to raise_error
      end

      it 'turns snake case symbols into camel case symbols' do
        snake = :hello_world
        camel = UtilTest.new.camel_case(snake)
        expect(camel).to eq(:helloWorld)

        snake = :hello
        camel = UtilTest.new.camel_case(snake)
        expect(camel).to eq(:hello)
      end

      it 'turns snake case strings into camel case strings' do
        snake = "hello_world"
        camel = UtilTest.new.camel_case(snake)
        expect(camel).to eq("helloWorld")

        snake = "hello"
        camel = UtilTest.new.camel_case(snake)
        expect(camel).to eq("hello")
      end

      it 'converts hash keys into camel case' do
        h = {
          :hello_world => 'x',
          :y => 'z',
        }
        camel_hash = UtilTest.new.camelize_hash(h)
        expect(camel_hash.keys.sort).to eq([:helloWorld, :y])
      end
    end
  end
end