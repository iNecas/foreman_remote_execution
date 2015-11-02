class InputTemplateRenderer
  class UndefinedInput < ::Foreman::Exception
  end

  include UnattendedHelper

  attr_accessor :template, :host, :invocation, :error_message

  # takes template object that should be rendered
  # host and template invocation arguments are optional
  # so we can render values based on parameters, facts or user inputs
  def initialize(template, host = nil, invocation = nil, template_value = template.template)
    @host = host
    @invocation = invocation
    @template = template
    @template_value = template_value
  end

  def render
    render_safe(@template_value, ::Foreman::Renderer::ALLOWED_HELPERS + [ :input, :ansible_input_hosts], :host => @host)
  rescue => e
    self.error_message ||= _('error during rendering: %s') % e.message
    Rails.logger.debug e.to_s + "\n" + e.backtrace.join("\n")
    return false
  end

  def preview
    @preview = true
    output = render
    @preview = false
    output
  end

  def input(name)
    input = input_by_name(name)
    if input
      @preview ? input.preview(self) : input.value(self)
    else
      self.error_message = _('input macro with name \'%s\' used, but no input with such name defined for this template') % name
      raise UndefinedInput, "Rendering failed, no input with name #{name} for input macro found"
    end
  end

  def ansible_input_hosts(name)
    if @preview
      "ansible_input_hosts(:#{name})"
    elsif input = input_by_name(name)
      search = input.value(self)
      hosts = invocation.job_invocation.targeting.targeting_scope.search_for(search)
      "[#{ hosts.map(&:hostname).join(', ') }]"
    end
  end

  def logger
    Rails.logger
  end

  private

  def input_by_name(name)
    @template.template_inputs.where(:name => name.to_s).first || @template.template_inputs.detect { |i| i.name == name.to_s }
  end
end
