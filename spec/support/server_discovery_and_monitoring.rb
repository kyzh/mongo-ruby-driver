# Matcher for determining if the server is of the expected type according to
# the test.
#
# @since 2.0.0
RSpec::Matchers.define :be_server_type do |expected|

  match do |actual|
    case expected
      when 'Standalone' then actual.standalone?
      when 'RSPrimary' then actual.primary?
      when 'RSSecondary' then actual.secondary?
      when 'RSArbiter' then actual.arbiter?
      when 'Mongos' then actual.mongos?
      when 'Unknown' then actual.unknown?
      when 'PossiblePrimary' then actual.unknown?
      when 'RSGhost' then actual.ghost?
      when 'RSOther' then actual.other?
    end
  end
end

# Matcher for determining if the cluster topology is the expected type.
#
# @since 2.0.0
RSpec::Matchers.define :be_topology do |expected|

  match do |actual|
    case expected
      when 'ReplicaSetWithPrimary' then actual.replica_set?
      when 'ReplicaSetNoPrimary' then actual.replica_set?
      when 'Sharded' then actual.sharded?
      when 'Single' then actual.standalone?
      when 'Unknown' then actual.unknown?
    end
  end
end

module Mongo
  module SDAM

    # Convenience helper to find a server by it's URI.
    #
    # @since 2.0.0
    def find_server(client, uri)
      client.cluster.instance_variable_get(:@servers).detect{ |s| s.address.to_s == uri }
    end

    # Represents a specification.
    #
    # @since 2.0.0
    class Spec

      # @return [ String ] description The spec description.
      attr_reader :description

      # @return [ Array<Phase> ] phases The spec phases.
      attr_reader :phases

      # @return [ Mongo::URI ] uri The URI object.
      attr_reader :uri

      # @return [ String ] uri_string The passed uri string.
      attr_reader :uri_string

      # Instantiate the new spec.
      #
      # @example Create the spec.
      #   Spec.new(file)
      #
      # @param [ String ] file The name of the file.
      #
      # @since 2.0.0
      def initialize(file)
        @test = YAML.load(ERB.new(File.new(file).read).result)
        @description = @test['description']
        @uri_string = @test['uri']
        @uri = URI.new(uri_string)
        @phases = @test['phases'].map{ |phase| Phase.new(phase, uri) }
      end
    end

    # Represents a phase in the spec. Phases are sequential.
    #
    # @since 2.0.0
    class Phase

      # @return [ Outcome ] outcome The phase outcome.
      attr_reader :outcome

      # @return [ Array<Response> ] responses The responses for each server in
      #   the phase.
      attr_reader :responses

      # Create the new phase.
      #
      # @example Create the new phase.
      #   Phase.new(phase, uri)
      #
      # @param [ Hash ] phase The phase hash.
      # @param [ Mongo::URI ] uri The URI.
      #
      # @since 2.0.0
      def initialize(phase, uri)
        @phase = phase
        @responses = @phase['responses'].map{ |response| Response.new(response, uri) }
        @outcome = Outcome.new(@phase['outcome'])
      end
    end

    # Represents a server response during a phase.
    #
    # @since 2.0.0
    class Response

      # @return [ String ] address The server address.
      attr_reader :address

      # @return [ Hash ] ismaster The ismaster response.
      attr_reader :ismaster

      # Create the new response.
      #
      # @example Create the response.
      #   Response.new(response, uri)
      #
      # @param [ Hash ] response The response value.
      # @param [ Mongo::URI ] uri The URI.
      #
      # @since 2.0.0
      def initialize(response, uri)
        @uri = uri
        @address = response[0]
        @ismaster = response[1]
      end
    end

    # Get the outcome or expectations from the phase.
    #
    # @since 2.0.0
    class Outcome

      # @return [ Array<Array<String, Hash>>] servers The expecations for
      #   server states.
      attr_reader :servers

      # @return [ String ] set_name The expected RS set name.
      attr_reader :set_name

      # @return [ String ] topology_type The expected cluster topology type.
      attr_reader :topology_type

      # Create the new outcome.
      #
      # @example Create the new outcome.
      #   Outcome.new(outcome)
      #
      # @param [ Hash ] outcome The outcome object.
      #
      # @since 2.0.0
      def initialize(outcome)
        @servers = outcome['servers']
        @set_name = outcome['setName']
        @topology_type = outcome['topologyType']
      end
    end
  end
end
