module Actions
  module RemoteExecution

    class ForemanObjectsSerializer < ::Dynflow::Serializers::Abstract
      def serialize(*args)
        args.map do |arg|
          if arg.is_a? ActiveRecord::Base
            { :active_record_object => true,
              :class_name => arg.class.name,
              :id => arg.id }
          else
            arg
          end
        end
      end

      def deserialize(serialized_args)
        serialized_args.map do |arg|
          if arg.is_a?(Hash) && arg[:active_record_object]
            arg[:class_name].constantize.find(arg[:id])
          else
            arg
          end
        end
      end
    end

    class JobRun < Actions::ActionWithSubPlans

      def schedule(schedule_options, *args)
        ForemanObjectsSerializer.new
      end

      def plan(job_invocation)
        job_invocation.targeting.resolve_hosts!
        input.update(:job_name => job_invocation.job_name)
        plan_self(job_invocation_id: job_invocation.id)
      end

      def create_sub_plans
        job_invocation = JobInvocation.find(input[:job_invocation_id])
        job_invocation.targeting.hosts.map do |host|
          trigger(JobRunHost, job_invocation, host)
        end
      end

      def rescue_strategy
        ::Dynflow::Action::Rescue::Skip
      end

      def run(event = nil)
        super unless event == Dynflow::Action::Skip
      end
    end
  end
end
