require "clamp"
require "console_logger"
require "pager_judy/api/client"
require "pager_judy/cli/collection_behaviour"
require "pager_judy/cli/item_behaviour"
require "pager_judy/cli/time_filtering"
require "pager_judy/sync"
require "pager_judy/version"

module PagerJudy
  module CLI

    class MainCommand < Clamp::Command

      option "--debug", :flag, "enable debugging"
      option "--dry-run", :flag, "enable dry-run mode"

      option "--version", :flag, "display version" do
        puts PagerJudy::VERSION
        exit 0
      end

      option "--api-key", "KEY", "PagerDuty API key",
             environment_variable: "PAGER_DUTY_API_KEY"

      subcommand ["escalation-policy", "ep"], "Display escalation policy" do

        parameter "ID", "escalation_policy ID"

        include ItemBehaviour

        def item
          client.escalation_policies[id]
        end

      end

      subcommand ["escalation_policies", "eps"], "Display escalation policies" do

        option %w[-q --query], "FILTER", "name filter"

        include CollectionBehaviour

        def collection
          client.escalation_policies.with(query: query)
        end

      end

      subcommand ["incidents"], "Display incidents" do

        option %w[-s --status], "STATUS", "status", :multivalued => true

        include CollectionBehaviour
        include TimeFiltering

        def collection
          client.incidents.with(filters)
        end

        def filters
          time_filters.merge("statuses[]" => status_list).select { |_,v| v }
        end

      end

      subcommand "schedule", "Display schedule" do

        parameter "ID", "schedule ID"

        include ItemBehaviour

        def item
          client.schedules[id]
        end

      end

      subcommand "schedules", "Display schedules" do

        option %w[-q --query], "FILTER", "name filter"

        include CollectionBehaviour

        def collection
          client.schedules.with(query: query)
        end

      end

      subcommand "service", "Display service" do

        option %w[--include], "TYPE", "linked objects to include", :multivalued => true

        parameter "ID", "service ID"

        include ItemBehaviour

        def item
          client.services[id].with(
            "include[]" => include_list
          )
        end

      end

      subcommand "services", "Display services" do

        option %w[-q --query], "FILTER", "name filter"
        option %w[--team], "ID", "team ID", :multivalued => true
        option %w[--include], "TYPE", "linked objects to include", :multivalued => true

        include CollectionBehaviour

        def collection
          client.services.with(
            "query" => query,
            "team_ids[]" => team_list,
            "include[]" => include_list
          )
        end

      end

      subcommand "team", "Display team" do

        parameter "ID", "team ID"

        include ItemBehaviour

        def item
          client.teams[id]
        end

      end

      subcommand "teams", "Display teams" do

        option %w[-q --query], "FILTER", "name filter"

        include CollectionBehaviour

        def collection
          client.teams.with(query: query)
        end

      end

      subcommand "user", "Display user" do

        parameter "ID", "user ID"

        include ItemBehaviour

        def item
          client.users[id]
        end

      end

      subcommand "users", "User operations" do

        include CollectionBehaviour

        def collection
          client.users
        end

      end

      subcommand "vendor", "Specific vendor" do

        parameter "ID", "vendor ID"

        include ItemBehaviour

        def item
          client.vendors[id]
        end

      end

      subcommand "vendors", "Vendor list" do

        include CollectionBehaviour

        def collection
          client.vendors
        end

      end

      subcommand "viz", "Generate Graphviz Dot diagram" do

        def execute
          services = client.services
          escalation_policies = client.escalation_policies
          puts %(digraph pagerduty {)
          puts %(rankdir=LR;)
          integrations = []
          services.each do |service|
            service.fetch('integrations').each do |integration|
              integrations << integration
              puts %(#{integration.fetch('id')} -> #{service.fetch('id')};)
              puts %(#{integration.fetch('id')} [label="#{integration.fetch('summary')}",shape=box];)
            end
          end
          puts same_rank(integrations)
          services.each do |service|
            puts %(#{service.fetch('id')} [label="#{service.fetch('name')}",shape=box,style=filled,color=lightgrey];)
            ep = service['escalation_policy']
            if ep
              puts %(#{service.fetch('id')} -> #{ep.fetch('id')};)
            end
          end
          puts same_rank(services)
          escalation_targets = {}
          escalation_policies.each do |ep|
            puts %{#{ep.fetch('id')} [label="#{ep.fetch('name')}",shape=box,style=filled,color=lightgrey];}
            ep.fetch('escalation_rules').each do |rule|
              rule.fetch('targets').each do |target|
                puts %(#{ep.fetch('id')} -> #{target.fetch('id')};)
                escalation_targets[target.fetch('id')] = target.fetch('summary')
              end
            end
          end
          puts same_rank(escalation_policies)
          escalation_targets.each do |id, summary|
            puts %(#{id} [label="#{summary}",shape=box];)
          end
          puts %(})
        end

        private

        def same_rank(things)
          ids = things.map { |thing| thing.fetch('id') }
          "{" + ["rank=same", *ids].join(';') + "}"
        end

      end

      subcommand "configure", "Apply config" do

        option "--check", :flag, "just validate the config"

        parameter "SOURCE", "config file"

        def execute
          config = PagerJudy::Sync::Config.from(source)
          return if check?
          PagerJudy::Sync.sync(client: client, config: config)
        end

      end

      def run(*args)
        super(*args)
      rescue PagerJudy::API::HttpError => e
        $stderr.puts e.response.body
        signal_error e.message
      rescue ConfigMapper::MappingError => e
        signal_error e.message
      end

      private

      def client
        signal_error "no --api-key provided" unless api_key
        HTTPI.log = false
        @client ||= PagerJudy::API::Client.new(api_key, logger: logger, dry_run: dry_run?)
      end

      def logger
        @logger ||= ConsoleLogger.new(STDERR, debug?)
      end

    end

  end
end
