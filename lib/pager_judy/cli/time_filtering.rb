require "clamp"
require "time"


module PagerJudy
  module CLI

    module TimeFiltering

      DAY = 24 * 60 * 60

      extend Clamp::Option::Declaration

      option %w[-a --after], "DATETIME", "start date/time", default: "24 hours ago", attribute_name: :after
      option %w[-b --before], "DATETIME", "end date/time", attribute_name: :before

      begin
        require "chronic"
        TimeParser = ::Chronic
      rescue LoadError
        TimeParser = ::Time
      end

      protected

      def time_filters
        {
          "since" => after,
          "until" => before
        }.select { |_,v| v }
      end

      private

      def after=(s)
        @after = TimeParser.parse(s)
      end

      def before=(s)
        @before = TimeParser.parse(s)
      end

      def default_after
        Time.now - DAY
      end

      def default_before
        Time.now
      end

    end

  end
end
