class SSHExecutionProvider < RemoteExecutionProvider
  class << self
    def proxy_command_options(template_invocation, host)
      super.merge(:ssh_user => ssh_user(host),
                  :effective_user => effective_user(template_invocation),
                  :effective_user_method => effective_user_method(host),
                  :cleanup_working_dirs => cleanup_working_dirs?(host),
                  :sudo_password => sudo_password(host),
                  :ssh_port => ssh_port(host))
    end

    def humanized_name
      _('SSH')
    end

    def supports_effective_user?
      true
    end

    def ssh_password(host)
      host_setting(host, :remote_execution_ssh_password)
    end

    def ssh_key_passphrase(host)
      host_setting(host, :remote_execution_ssh_key_passphrase)
    end

    def ssh_params(host)
      proxy_selector = ::RemoteExecutionProxySelector.new
      proxy = proxy_selector.determine_proxy(host, 'SSH')
      if proxy == :not_defined && Setting['remote_execution_without_proxy']
        proxy = :direct
      end
      params = {
        :hostname => find_ip_or_hostname(host),
        :proxy => proxy.class == Symbol ? proxy : proxy.url,
        :ssh_user => ssh_user(host),
        :ssh_port => ssh_port(host),
        :ssh_password => ssh_password(host),
        :ssh_key_passphrase => ssh_key_passphrase(host)
      }
      if proxy == :direct
        params[:ssh_key_file] = File.expand_path(ForemanRemoteExecutionCore.settings.fetch(:ssh_identity_key_file))
      end
      return params
    end

    private

    def ssh_user(host)
      host.host_param('remote_execution_ssh_user')
    end

    def ssh_port(host)
      Integer(host_setting(host, :remote_execution_ssh_port))
    end
  end
end
