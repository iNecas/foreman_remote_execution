module Actions
  module RemoteExecution
    class JobRun < Actions::ActionWithSubPlans
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
