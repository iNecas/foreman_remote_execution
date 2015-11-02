module Actions
  module RemoteExecution
    class RunHostsJob < Actions::ActionWithSubPlans

      middleware.use Actions::Middleware::BindJobInvocation

      def delay(delay_options, job_invocation)
        job_invocation.targeting.resolve_hosts! if job_invocation.targeting.static?
        action_subject(job_invocation)
        super(delay_options, job_invocation, true)
      end

      def plan(job_invocation, locked = false, connection_options = {})
        action_subject(job_invocation) unless locked
        job_invocation.targeting.resolve_hosts! if job_invocation.targeting.dynamic? || !locked
        input.update(:job_name => job_invocation.job_name)
        plan_self(:job_invocation_id => job_invocation.id, :connection_options => connection_options)
      end

      def create_sub_plans
        job_invocation = JobInvocation.find(input[:job_invocation_id])
        load_balancer = ProxyLoadBalancer.new

        # TODO: fix multi-templates case
        template_invocation = job_invocation.template_invocations.first

        case template_invocation.template.provider_type.to_s
          when 'Ssh'
            job_invocation.targeting.hosts.map do |host|
              template_invocation = job_invocation.template_invocation_for_host(host)
              proxy = determine_proxy(template_invocation, host, load_balancer)
              trigger(RunHostJob, job_invocation, host, template_invocation, proxy, input[:connection_options])
            end
          when 'Ansible'
            proxy = determine_proxy(template_invocation, job_invocation.targeting.hosts.first, load_balancer)

            sub_tasks = job_invocation.targeting.hosts.map do |host|
              trigger(AnsibleHostJob, job_invocation, host, template_invocation)
            end
            sub_tasks << trigger(RunAnsibleJob, job_invocation, template_invocation, proxy, input[:connection_options])
            sub_tasks
          else
            raise "Unsupported provider #{template_invocation.template.provider_type.to_s}"
        end
      end

      def rescue_strategy
        ::Dynflow::Action::Rescue::Skip
      end

      def run(event = nil)
        super unless event == Dynflow::Action::Skip
      end

      private

      def determine_proxy(template_invocation, host, load_balancer)
        provider = template_invocation.template.provider_type.to_s
        host_proxies = host.remote_execution_proxies(provider)
        strategies = [:subnet, :fallback, :global]
        proxy = nil

        strategies.each do |strategy|
          proxy = load_balancer.next(host_proxies[strategy]) if host_proxies[strategy].present?
          break if proxy
        end

        proxy
      end
    end
  end
end
