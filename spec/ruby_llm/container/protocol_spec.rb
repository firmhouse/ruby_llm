# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Container::Protocol do
  let(:connection) { instance_double(RubyLLM::Connection) }
  let(:provider) { instance_double(RubyLLM::Providers::OpenAI, connection:, slug: 'openai') }
  let(:protocol) { described_class.new(provider) }

  it 'creates and normalizes a container' do
    response = instance_double(Faraday::Response, body: {
                                 'id' => 'cntr_123',
                                 'name' => 'template-editor',
                                 'status' => 'running',
                                 'created_at' => 1_700_000_000,
                                 'last_active_at' => 1_700_000_010,
                                 'memory_limit' => '1g',
                                 'expires_after' => { 'anchor' => 'last_active_at', 'minutes' => 20 }
                               })
    allow(connection).to receive(:post).with(
      'containers',
      {
        name: 'template-editor',
        memory_limit: '1g',
        expires_after: { anchor: 'last_active_at', minutes: 20 }
      }
    ).and_return(response)

    container = protocol.create(
      name: 'template-editor',
      memory_limit: '1g',
      expires_after: { anchor: 'last_active_at', minutes: 20 }
    )

    expect(container).to have_attributes(
      id: 'cntr_123',
      provider: :openai,
      name: 'template-editor',
      status: 'running',
      memory_limit: '1g'
    )
  end

  it 'lists normalized container files' do
    response = instance_double(Faraday::Response, body: {
                                 'data' => [{
                                   'id' => 'cfile_123',
                                   'container_id' => 'cntr_123',
                                   'path' => '/mnt/data/dashboard.liquid',
                                   'bytes' => 42,
                                   'created_at' => 1_700_000_000
                                 }]
                               })
    allow(connection).to receive(:get).with('containers/cntr_123/files').and_return(response)

    files = protocol.list_files('cntr_123')

    expect(files.one?).to be(true)
    expect(files.first).to have_attributes(
      id: 'cfile_123',
      container_id: 'cntr_123',
      path: '/mnt/data/dashboard.liquid',
      byte_size: 42
    )
  end

  it 'downloads container file content as bytes' do
    response = instance_double(Faraday::Response, body: "template\n")
    allow(connection).to receive(:get).with('containers/cntr_123/files/cfile_123/content').and_yield(
      Struct.new(:headers).new({})
    ).and_return(response)

    expect(protocol.download_file('cntr_123', 'cfile_123')).to eq("template\n")
  end

  it 'uses an explicit content type for uploaded container files' do
    response = instance_double(Faraday::Response, body: {
                                 'id' => 'cfile_123',
                                 'container_id' => 'cntr_123',
                                 'path' => '/mnt/data/dashboard.liquid',
                                 'bytes' => 42
                               })
    allow(connection).to receive(:post).with('containers/cntr_123/files', anything).and_yield(
      Struct.new(:headers).new({})
    ).and_return(response)

    file = StringIO.new('<div>Customer portal</div>')
    protocol.upload_file('cntr_123', file, filename: 'dashboard.liquid', content_type: 'text/x-liquid')

    expect(connection).to have_received(:post) do |_path, payload|
      expect(payload.fetch(:file).content_type).to eq('text/x-liquid')
      expect(payload.fetch(:file).original_filename).to eq('dashboard.liquid')
    end
  end
end
