module Actions
  module RemoteExecution
    class RunProxyCommand < Actions::ProxyAction

      include ::Dynflow::Action::Cancellable

      def plan(proxy, hostname, script, options = {})
        options = default_connection_options
                  .merge({ :effective_user => nil })
                  .merge(options)
        super(proxy, options.merge(:hostname => hostname, :script => script))
      end

      def run(event = nil)
        with_connection_error_handling(event) { super(event) }
      end

      def proxy_action_name
        'Proxy::RemoteExecution::Ssh::CommandAction'
      end

      def on_data(data)
        if data[:result] == 'initialization_error'
          handle_connection_exception(data[:exception_class]
                                       .constantize
                                       .new(data[:exception_message]))
        else
          super(data)
          error! _("Script execution failed") if failed_run?
        end
      end

      def rescue_strategy
        ::Dynflow::Action::Rescue::Skip
      end

      def failed_run?
        event.data[:result] == 'initialization_error' ||
          (exit_status && proxy_output[:exit_status] != 0)
      end

      def exit_status
        proxy_output && proxy_output[:exit_status]
      end

      private

      def default_connection_options
        { :connection_options => { :retry_interval => 15, :retry_count => 4 } }
      end

      def handle_connection_exception(exception, event = nil)
        output[:failed_proxy_task_ids] ||= []
        options = input[:connection_options]
        if options[:retry_count] - output[:failed_proxy_task_ids].count > 0
          output[:failed_proxy_task_ids] << output[:proxy_task_id]
          output[:proxy_task_id] = nil
          suspend do |suspended_action|
            @world.clock.ping suspended_action,
                              Time.now + options[:retry_interval],
                              event
          end
        else
          raise exception
        end
      end

      def with_connection_error_handling(event = nil, &block)
        block.call() if block_given?
      rescue ::RestClient::Exception, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
        handle_connection_exception(e, event)
      end
    end
  end
end
