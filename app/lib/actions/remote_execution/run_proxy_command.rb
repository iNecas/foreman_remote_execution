module Actions
  module RemoteExecution
    class RunProxyCommand < Actions::ProxyAction

      include ::Dynflow::Action::Cancellable

      def on_data(data)
        if data[:result] == 'initialization_error'
          handle_connection_exception(data[:metadata][:exception_class]
                                       .constantize
                                       .new(data[:metadata][:exception_message]))
        else
          super(data)
        end
      end


      def rescue_strategy
        ::Dynflow::Action::Rescue::Skip
      end

      def exit_status
        proxy_output && proxy_output[:exit_status]
      end

      def live_output
        records = connection_messages
        if !task.pending?
          records.concat(finalized_output)
        else
          records.concat(current_proxy_output)
        end
        records.sort_by { |record| record['timestamp'].to_f }
      end

      private

      def connection_messages
        metadata.fetch(:failed_proxy_tasks, []).map do |failure_data|
          format_output(_('Initialization error: %s') % "#{failure_data[:exception_class]} - #{failure_data[:exception_message]}", 'debug', failure_data[:timestamp])
        end
      end

      def current_proxy_output
        return [] unless output[:proxy_task_id]
        proxy_data = proxy.status_of_task(output[:proxy_task_id])['actions'].detect { |action| action['class'] == proxy_action_name }
        proxy_data.fetch('output', {}).fetch('result', [])
      rescue => e
        ::Foreman::Logging.exception("Failed to load data for task #{task.id} from proxy #{ input[:proxy_url] }", e)
        [exception_to_output(_("Error loading data from proxy"), e)]
      end

      def finalized_output
        records = []
        if self.output[:proxy_output].present?
          records.concat(self.output[:proxy_output].fetch(:result, []))
        else
          records << format_output(_('No output'))
        end

        if exit_status
          records << format_output(_("Exit status: %s") % exit_status, 'stdout', task.ended_at)
        elsif run_step && run_step.error
          records << format_output(_("Job finished with error") + ": #{run_step.error.exception_class} - #{run_step.error.message}", 'debug', task.ended_at)
        end
        return records
      end

      def exception_to_output(context, exception, timestamp = Time.now)
        format_output(context + ": #{exception.class} - #{exception.message}", 'debug', timestamp)
      end

      def format_output(message, type = 'debug', timestamp = Time.now)
        { 'output_type' => type,
          'output' => message,
          'timestamp' => timestamp.to_f }
      end
    end
  end
end
