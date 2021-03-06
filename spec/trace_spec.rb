require 'spec_helper'
require 'time'

RSpec.describe Aws::Xray::Trace do
  describe '.build_from_header_value' do
    context 'with parent and sampled' do
      let(:v) { 'Root=1-5759e988-bd862e3fe1be46a994272793;Parent=53995c3f42cd8ad8;Sampled=1' }

      it 'created' do
        r = described_class.build_from_header_value(v)
        expect(r.root).to eq('1-5759e988-bd862e3fe1be46a994272793')
        expect(r.parent).to eq('53995c3f42cd8ad8')
        expect(r.sampled?).to eq(true)
      end

      it 'dumped' do
        r = described_class.build_from_header_value(v)
        expected = 'Root=1-5759e988-bd862e3fe1be46a994272793;Sampled=1;Parent=53995c3f42cd8ad8'
        expect(r.to_header_value).to eq(expected)
      end
    end

    context 'with custom fields' do
      let(:v) { 'Root=1-5759e988-bd862e3fe1be46a994272793;FieldB=yyy;FieldA=xxx;' }

      it 'created' do
        r = described_class.build_from_header_value(v)
        expect(r.root).to eq('1-5759e988-bd862e3fe1be46a994272793')
        expect(r.parent).to be_nil
        expect(r.sampled?).to eq(true)
      end

      it 'dumped fromated values keeping original order' do
        r = described_class.build_from_header_value(v)
        expected = 'Root=1-5759e988-bd862e3fe1be46a994272793;Sampled=1;FieldB=yyy;FieldA=xxx'
        expect(r.to_header_value).to eq(expected)
      end
    end
  end

  describe '.generate' do
    it 'returns newly created trace header' do
      now = Time.parse('2017/01/01 00:00:00Z')
      r = described_class.generate(now)
      epoch = r.root.scan(/\A1-([0-9A-Fa-f]+)-/).first.first
      expect(epoch.to_i(16)).to eq(now.to_i)
    end
  end

  describe 'sampling' do
    context 'when Sampled=0' do
      let(:header_value) { 'Sampled=0' }

      it 'follows header value' do
        100.times do
          trace = described_class.build_from_header_value(header_value)
          expect(trace.sampled?).to eq(false)
        end
      end
    end

    context 'when Sampled=1' do
      let(:header_value) { 'Sampled=1' }

      it 'follows header value' do
        100.times do
          trace = described_class.build_from_header_value(header_value)
          expect(trace.sampled?).to eq(true)
        end
      end
    end

    context 'when no Sampled value' do
      it 'decides sampled or not with configuration' do
        100.times do
          allow(Aws::Xray.config).to receive(:sampling_rate).and_return(0)
          trace = described_class.build_from_header_value('')
          expect(trace.sampled?).to eq(false)

          allow(Aws::Xray.config).to receive(:sampling_rate).and_return(1)
          trace = described_class.build_from_header_value('')
          expect(trace.sampled?).to eq(true)
        end
      end
    end

    context 'when Sampled=abc' do
      let(:header_value) { 'Sampled=abc' }

      it 'decides sampled or not with configuration' do
        100.times do
          allow(Aws::Xray.config).to receive(:sampling_rate).and_return(0)
          trace = described_class.build_from_header_value(header_value)
          expect(trace.sampled?).to eq(false)

          allow(Aws::Xray.config).to receive(:sampling_rate).and_return(1)
          trace = described_class.build_from_header_value(header_value)
          expect(trace.sampled?).to eq(true)
        end
      end
    end

    context 'when Sampled=' do
      let(:header_value) { 'Sampled=' }

      it 'decides sampled or not with configuration' do
        100.times do
          allow(Aws::Xray.config).to receive(:sampling_rate).and_return(0)
          trace = described_class.build_from_header_value(header_value)
          expect(trace.sampled?).to eq(false)

          allow(Aws::Xray.config).to receive(:sampling_rate).and_return(1)
          trace = described_class.build_from_header_value(header_value)
          expect(trace.sampled?).to eq(true)
        end
      end
    end

    context 'when Sampled=true' do
      let(:header_value) { 'Sampled=true' }

      it 'decides sampled or not with configuration' do
        100.times do
          allow(Aws::Xray.config).to receive(:sampling_rate).and_return(0)
          trace = described_class.build_from_header_value(header_value)
          expect(trace.sampled?).to eq(false)

          allow(Aws::Xray.config).to receive(:sampling_rate).and_return(1)
          trace = described_class.build_from_header_value(header_value)
          expect(trace.sampled?).to eq(true)
        end
      end
    end
  end
end
