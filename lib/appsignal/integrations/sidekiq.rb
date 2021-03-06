if defined?(::Sidekiq)
  Appsignal.logger.info('Loading Sidekiq integration')

  module Appsignal
    module Integrations
      class SidekiqPlugin
        def call(worker, item, queue)
          Appsignal::Transaction.create(SecureRandom.uuid, ENV)
          ActiveSupport::Notifications.instrument(
            'perform_job.sidekiq',
            :class => item['class'],
            :method => 'perform',
            :attempts => item['retry_count'],
            :queue => item['queue'],
            :queue_start => item['enqueued_at']
          ) do
            yield
          end
        rescue Exception => exception
          unless Appsignal.is_ignored_exception?(exception)
            Appsignal::Transaction.current.add_exception(exception)
          end
          raise exception
        ensure
          Appsignal::Transaction.current.complete!
        end
      end
    end
  end

  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add Appsignal::Integrations::SidekiqPlugin
    end
  end
end
