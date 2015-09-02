require "test_plugin_helper"

module ForemanRemoteExecution
  class RunProxyCommandTest <  ActiveSupport::TestCase
    include Dynflow::Testing

    let(:proxy) { FactoryGirl.build(:smart_proxy) }
    let(:hostname) { 'myhost.example.com' }
    let(:script) { 'ping -c 5 redhat.com' }
    let(:connection_options) { { 'retry_interval' => 15, 'retry_count' => 4 } }
    let(:action) do
      create_and_plan_action(Actions::RemoteExecution::RunProxyCommand, proxy, hostname, script)
    end

    it 'plans for running the command action on server' do
      assert_run_phase action, { :connection_options => connection_options,
                                 :hostname           => hostname,
                                 :script             => script,
                                 :proxy_url          => proxy.url,
                                 :effective_user     => nil }
    end

    it 'sends to command to ssh provider' do
      action.proxy_action_name.must_equal 'Proxy::RemoteExecution::Ssh::CommandAction'
    end

    it "doesn't block on failure" do
      action.rescue_strategy.must_equal ::Dynflow::Action::Rescue::Skip
    end

    it 'handles connection errors' do
      action = self.action
      run_stubbed_action = ->(action) do
        run_action action do |action|
          action.expects(:trigger_proxy_task).raises(Errno::ECONNREFUSED.new('Connection refused'))
        end
      end
      action = run_stubbed_action.call action
      action.state.must_equal :suspended
      action.world.clock.pending_pings.length.must_equal 1
      action.output[:metadata][:failed_proxy_tasks].length.must_equal 1
      2.times { action.output[:metadata][:failed_proxy_tasks] << {} }
      proc { action = run_stubbed_action.call action }.must_raise(Errno::ECONNREFUSED)
      action.state.must_equal :error
    end

  end
end
