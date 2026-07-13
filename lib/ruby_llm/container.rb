# frozen_string_literal: true

module RubyLLM
  # A provider-hosted execution container and its downloadable files.
  class Container
    attr_reader :id, :provider, :name, :status, :created_at, :expires_after,
                :last_active_at, :memory_limit, :metadata

    def initialize(id:, provider:, context: nil, **attributes) # :nodoc:
      @id = id
      @provider = provider.to_sym
      @context = context
      @name = attributes[:name]
      @status = attributes[:status]
      @created_at = attributes[:created_at]
      @expires_after = attributes[:expires_after]
      @last_active_at = attributes[:last_active_at]
      @memory_limit = attributes[:memory_limit]
      @metadata = attributes[:metadata] || {}
    end

    def upload(file, filename: nil)
      provider_instance.upload_container_file(id, file, filename:)
    end

    def files
      provider_instance.list_container_files(id)
    end

    def download(file_id)
      provider_instance.download_container_file(id, file_id)
    end

    def delete
      provider_instance.delete_container(id)
    end

    class Protocol # :nodoc:
      def initialize(provider)
        @provider = provider
        @connection = provider.connection
      end

      def create(name:, memory_limit: nil, expires_after: nil, network_policy: nil)
        payload = { name:, memory_limit:, expires_after:, network_policy: }.compact
        parse_container(@connection.post('containers', payload).body)
      end

      def find(id)
        parse_container(@connection.get("containers/#{id}").body)
      end

      def delete(id)
        @connection.delete("containers/#{id}").body
      end

      def upload_file(container_id, file, filename: nil)
        attachment = file.is_a?(Attachment) && filename.nil? ? file : Attachment.new(file, filename:)
        payload = { file: file_part(attachment) }
        response = @connection.post("containers/#{container_id}/files", payload) do |request|
          request.headers.delete('Content-Type')
        end
        parse_container_file(response.body)
      end

      def list_files(container_id)
        response = @connection.get("containers/#{container_id}/files")
        Array(response.body['data']).map { |data| parse_container_file(data) }
      end

      def download_file(container_id, file_id)
        response = @connection.get("containers/#{container_id}/files/#{file_id}/content") do |request|
          request.headers['Accept'] = 'application/octet-stream'
        end
        response.body
      end

      private

      def parse_container(data)
        Container.new(
          id: data.fetch('id'),
          provider: @provider.slug,
          name: data['name'],
          status: data['status'],
          created_at: timestamp(data['created_at']),
          expires_after: data['expires_after'],
          last_active_at: timestamp(data['last_active_at']),
          memory_limit: data['memory_limit'],
          metadata: data
        )
      end

      def parse_container_file(data)
        ContainerFile.new(
          id: data.fetch('id'),
          container_id: data.fetch('container_id'),
          path: data['path'],
          byte_size: data['bytes'],
          created_at: timestamp(data['created_at']),
          metadata: data
        )
      end

      def file_part(attachment)
        Faraday::Multipart::FilePart.new(
          file_part_source(attachment),
          attachment.mime_type,
          attachment.filename
        )
      end

      def file_part_source(attachment)
        return attachment.source.to_s if attachment.path?
        return attachment.source.tap { |io| io.rewind if io.respond_to?(:rewind) } if attachment.io_like?

        StringIO.new(attachment.content)
      end

      def timestamp(value)
        return if value.nil?

        Time.at(value.to_i)
      end
    end

    def self.create(name:, provider: :openai, context: nil, **options)
      provider_for(provider, context).create_container(name:, **options).tap do |container|
        container.instance_variable_set(:@context, context)
      end
    end

    def self.find(id, provider: :openai, context: nil)
      provider_for(provider, context).find_container(id).tap do |container|
        container.instance_variable_set(:@context, context)
      end
    end

    def self.provider_for(provider, context)
      config = context&.config || RubyLLM.config
      Provider.resolve!(provider).new(config)
    end
    private_class_method :provider_for

    private

    def provider_instance
      self.class.send(:provider_for, provider, @context)
    end
  end
end
