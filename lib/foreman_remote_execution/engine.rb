module ForemanRemoteExecution
  class Engine < ::Rails::Engine
    engine_name 'foreman_remote_execution'

    config.autoload_paths += Dir["#{config.root}/app/controllers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/helpers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/models/concerns"]

    # Add any db migrations
    initializer 'foreman_remote_execution.load_app_instance_data' do |app|
      app.config.paths['db/migrate'] += ForemanRemoteExecution::Engine.paths['db/migrate'].existent
    end

    initializer 'foreman_remote_execution.assets.precompile' do |app|
      app.config.assets.precompile += %w(
        'template_input.js',
      )
    end

    initializer 'foreman_remote_execution.configure_assets', :group => :assets do
      SETTINGS[:foreman_remote_execution] =
        {:assets => {:precompile => [
          'template_input.js',
        ]}}
    end

    initializer "foreman_remote_execution.apipie" do
      Apipie.configuration.checksum_path += ['/api/']
    end

    initializer 'foreman_remote_execution.register_plugin', after: :finisher_hook do |_app|
      Foreman::Plugin.register :foreman_remote_execution do
        requires_foreman '>= 1.9'

        apipie_documented_controllers ["#{ForemanRemoteExecution::Engine.root}/app/controllers/api/v2/*.rb"]

        # Add permissions
        security_block :foreman_remote_execution do
          permission :view_job_templates, { :job_templates => [:index, :show, :revision, :auto_complete_search, :auto_complete_job_name],
                                            :'api/v2/job_templates' => [:index, :show, :revision]}, :resource_type => 'JobTemplate'

          permission :create_job_templates, { :job_templates => [:new, :create, :clone_template],
                                              :'api/v2/job_templates' => [:create, :clone]}, :resource_type => 'JobTemplate'

          permission :edit_job_templates, { :job_templates => [:edit, :update],
                                            :'api/v2/job_templates' => [:update]}, :resource_type => 'JobTemplate'

          permission :destroy_job_templates, { :job_templates => [:destroy],
                                               :'api/v2/job_templates' => [:destroy]}, :resource_type => 'JobTemplate'

          permission :lock_job_templates, { :job_templates => [:lock, :unlock] }, :resource_type => 'JobTemplate'
        end

        # Add a new role called 'ForemanRemoteExecution' if it doesn't exist
        # role 'ForemanRemoteExecution', [:view_foreman_remote_execution]

        # add menu entry
        menu :top_menu, :job_templates,
             url_hash: { controller: :job_templates, action: :index },
             caption: N_('Job templates'),
             parent: :hosts_menu,
             after: :provisioning_templates

        # add dashboard widget
        # widget 'foreman_remote_execution_widget', name: N_('Foreman plugin template widget'), sizex: 4, sizey: 1
      end
    end

    # Precompile any JS or CSS files under app/assets/
    # If requiring files from each other, list them explicitly here to avoid precompiling the same
    # content twice.
    assets_to_precompile =
      Dir.chdir(root) do
        Dir['app/assets/javascripts/**/*', 'app/assets/stylesheets/**/*'].map do |f|
          f.split(File::SEPARATOR, 4).last
        end
      end
    initializer 'foreman_remote_execution.assets.precompile' do |app|
      app.config.assets.precompile += assets_to_precompile
    end
    initializer 'foreman_remote_execution.configure_assets', group: :assets do
      SETTINGS[:foreman_remote_execution] = { assets: { precompile: assets_to_precompile } }
    end

    # Include concerns in this config.to_prepare block
    config.to_prepare do
      # we have to define associations in Template and all descendants because
      # reflect_on_association does not work when we add association after parent and child class
      # are already loaded, causing issues when you try to destroy any child which iterates
      # over all associations because of :dependant => :destroy
      #
      # e.g. having ProvisioningTemplate < Template, adding has_many :template_inputs to Template from concern
      #   Template.reflect_on_association :template_inputs # => <#Association...
      #   ProvisioningTemplate.reflect_on_association :template_inputs # => nil
      require_dependency 'job_template'
      (Template.descendants + [Template]).each { |klass| klass.send(:include, ForemanRemoteExecution::TemplateRelations) }

      Template.send(:include, ForemanRemoteExecution::TemplateExtensions)
      User.send(:include, ForemanRemoteExecution::UserExtensions)
      Bookmark.send(:include, ForemanRemoteExecution::BookmarkExtensions)
    end

    initializer 'foreman_remote_execution.register_gettext', after: :load_config_initializers do |_app|
      locale_dir = File.join(File.expand_path('../../..', __FILE__), 'locale')
      locale_domain = 'foreman_remote_execution'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end
  end
end
