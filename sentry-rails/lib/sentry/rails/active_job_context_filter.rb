module Sentry
  module Rails
    class ActiveJobContextFilter
      ACTIVEJOB_RESERVED_PREFIX_REGEX = /^_aj_/.freeze

      def transaction_name_prefix
        ::ActiveJob.name
      end

      attr_reader :context

      def initialize(context)
        @context = context
        @has_global_id = defined?(GlobalID)
      end

      # Once an ActiveJob is queued, ActiveRecord references get serialized into
      # some internal reserved keys, such as _aj_globalid.
      #
      # The problem is, if this job in turn gets queued back into ActiveJob with
      # these magic reserved keys, ActiveJob will throw up and error. We want to
      # capture these and mutate the keys so we can sanely report it.
      def filtered
        filter_context(context)
      end

      def transaction_name
        class_name = (context["wrapped"] || context["class"] ||
                      (context[:job] && (context[:job]["wrapped"] || context[:job]["class"]))
                    )

        if class_name
          "#{transaction_name_prefix}/#{class_name}"
        elsif context[:event]
          "#{transaction_name_prefix}/#{context[:event]}"
        else
          transaction_name_prefix
        end
      end

      private

      def filter_context(hash)
        case hash
        when Array
          hash.map { |arg| filter_context(arg) }
        when Hash
          Hash[hash.map { |key, value| filter_context_hash(key, value) }]
        else
          if has_global_id? && hash.is_a?(GlobalID)
            hash.to_s
          else
            hash
          end
        end
      end

      def filter_context_hash(key, value)
        key = key.to_s.sub(ACTIVEJOB_RESERVED_PREFIX_REGEX, "") if key.match(ACTIVEJOB_RESERVED_PREFIX_REGEX)
        [key, filter_context(value)]
      end

      def has_global_id?
        @has_global_id
      end
    end
  end
end
