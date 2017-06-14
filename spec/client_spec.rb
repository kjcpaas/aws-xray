require 'spec_helper'

RSpec.describe Aws::Xray::Client do
  describe '#send_segment' do
    def build_server
      s = UDPSocket.new
      s.bind('127.0.0.1', 0)
      s
    end
    let(:segment) { double('segment', to_json: payload.to_json) }
    let(:payload) { { 'id' => 'abc' } }

    # Because rspec changes `$stderr` to StringIO.
    let(:io) { StringIO.new }
    around do |ex|
      back = Aws::Xray.config.segment_sending_error_handler
      Aws::Xray.config.segment_sending_error_handler = Aws::Xray::DefaultErrorHandler.new(io)
      ex.run
      Aws::Xray.config.segment_sending_error_handler = back
    end

    context 'success case' do
      it 'sends given segment' do
        s = build_server
        client = described_class.new(host: '127.0.0.1', port: s.addr[1])

        client.send_segment(segment)

        sent = s.recvfrom(1024)[0]
        expect(sent.split("\n").size).to eq(2)

        header, body = sent.split("\n").map {|e| JSON.parse(e) }
        expect(header).to eq('format' => 'json', 'version' => 1)
        expect(body).to eq(payload)
      end
    end

    context 'when too large payload is about to sent' do
      # Build as much as large payload to occur Errno::EMSGSIZE.
      # This is not platform compatible solution though...
      let(:payload) { { 'data' => 'abc' * 100000 } }

      it 'ignores system call erros' do
        s = build_server
        client = described_class.new(host: '127.0.0.1', port: s.addr[1])

        client.send_segment(segment)
        expect(io.tap(&:rewind).read).to match(/Failed to send a segment/)
      end
    end

    context 'when invalid hostname is specified' do
      it 'ignores socket errors' do
        client = described_class.new(host: 'aws-xray-gem-invalid-host-name', port: 8000)
        client.send_segment(segment)
        expect(io.tap(&:rewind).read).to match(/Failed to send a segment/)
      end
    end

    context 'when invalid port is specified' do
      it 'ignores socket errors' do
        client = described_class.new(host: '127.0.0.1', port: 0)
        client.send_segment(segment)
        expect(io.tap(&:rewind).read).to match(/Failed to send a segment/)
      end
    end

    context 'when error handler raises errors' do
      around do |ex|
        back = Aws::Xray.config.segment_sending_error_handler
        Aws::Xray.config.segment_sending_error_handler = -> (*) { raise 'test error' }
        ex.run
        Aws::Xray.config.segment_sending_error_handler = back
      end

      it 'rescues the error and log them' do
        client = described_class.new(host: '127.0.0.1', port: 0)
        expect { client.send_segment(segment) }.to output(/test error/).to_stderr
      end
    end

    context 'when error handler raises errors' do
      around do |ex|
        back = Aws::Xray.config.segment_sending_error_handler
        Aws::Xray.config.segment_sending_error_handler = Aws::Xray::ErrorHandlerWithSentry.new
        ex.run
        Aws::Xray.config.segment_sending_error_handler = back
      end

      it 'does not do nothing' do
        client = described_class.new(host: '127.0.0.1', port: 0)
        expect {
          client.send_segment(segment)
        }.to output(/ErrorHandlerWithSentry is configured but `Raven` is undefined./).to_stderr
      end
    end
  end
end
