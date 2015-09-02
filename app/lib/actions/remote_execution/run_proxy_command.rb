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
          handle_connection_exception(data[:metadata][:exception_class]
                                       .constantize
                                       .new(data[:metadata][:exception_message]))
        else
          super(data)
          error! _("Script execution failed") if failed_run?
        end
      end

      def trigger_proxy_task
        suspend do |suspended_action|
          output[:metadata] ||= {}
          unless metadata[:timeout]
            time = Time.now + input[:connection_options][:timeout]
            @world.clock.ping suspended_action,
                              time,
                              Timeout.new
            metadata[:timeout] = time.to_s
          end
          super
        end
      end

      def check_task_status
        if output[:proxy_task_id]
          response = proxy.task_status(output[:proxy_task_id])
          if response['state'] == 'stopped'
            if response['result'] == 'error'
              raise ::Foreman::Exception.new _("The smart proxy task '#{output[:proxy_task_id]}' failed.")
            else
              action = response['actions'].select { |action| action['class'] == proxy_action_name }.first
              on_data(action['output'])
            end
          else
           cancel_proxy_task
          end
        else
          raise ::Foreman::Exception.new _("Task wasn't triggered on the smart proxy in time.")
        end
      end

      def rescue_strategy
        ::Dynflow::Action::Rescue::Skip
      end

      def failed_run?
        output[:result] == 'initialization_error' ||
          (exit_status && proxy_output[:exit_status] != 0)
      end

      def exit_status
        proxy_output && proxy_output[:exit_status]
      end

      def metadata
        output[:metadata]
      end

      def metadata=(thing)
        output[:metadata] = thing
      end

      private

      def default_connection_options
        # Fails if the plan is not finished within 60 seconds from the first task trigger attempt on the smart proxy
        # If the triggering fails, it retries 3 more times with 15 second delays
        { :connection_options => { :retry_interval => 15, :retry_count => 4, :timeout => 60 } }
      end

      def handle_connection_exception(exception, event = nil)
        output[:metadata] ||= {}
        metadata[:failed_proxy_tasks] ||= []
        options = input[:connection_options]
        metadata[:failed_proxy_tasks] << format_exception(exception)
        output[:proxy_task_id] = nil
        if metadata[:failed_proxy_tasks].count < options[:retry_count]
          suspend do |suspended_action|
            @world.clock.ping suspended_action,
                              Time.now + options[:retry_interval],
                              event
          end
        else
          raise exception
        end
      end

      def format_exception(exception)
        { output[:proxy_task_id] =>
          { :exception_class => exception.class.name,
            :execption_message => exception.message } }
      end

      def with_connection_error_handling(event = nil)
        yield
      rescue ::RestClient::Exception, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
        if event.class == CallbackData || event.class == Timeout
          raise e
        else
          handle_connection_exception(e, event)
        end
      end
    end
  end
end
