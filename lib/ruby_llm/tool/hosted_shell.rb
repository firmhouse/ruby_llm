# frozen_string_literal: true

module RubyLLM
  class Tool
    # OpenAI's provider-hosted shell tool for the Responses API.
    # Commands execute inside an OpenAI-managed container and therefore do
    # not enter RubyLLM's local function-tool execution loop.
    class HostedShell < Tool
      attr_reader :container_id, :network_policy

      def initialize(container_id: nil, network_policy: nil)
        super()
        @container_id = container_id
        @network_policy = network_policy
      end

      def name
        'shell'
      end

      def built_in?
        true
      end

      def built_in_definition
        {
          type: 'shell',
          environment: environment
        }
      end

      private

      def environment
        definition = if container_id
                       { type: 'container_reference', container_id: container_id }
                     else
                       { type: 'container_auto' }
                     end
        definition[:network_policy] = network_policy if network_policy
        definition
      end
    end
  end
end
