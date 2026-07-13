# frozen_string_literal: true

module RubyLLM
  # Metadata for a file stored in a provider-hosted container.
  class ContainerFile
    attr_reader :id, :container_id, :path, :byte_size, :created_at, :metadata

    def initialize(id:, container_id:, **attributes)
      @id = id
      @container_id = container_id
      @path = attributes[:path]
      @byte_size = attributes[:byte_size]
      @created_at = attributes[:created_at]
      @metadata = attributes[:metadata] || {}
    end
  end
end
