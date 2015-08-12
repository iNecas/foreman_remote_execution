module RemoteExecutionHelper
  def providers_options
    RemoteExecutionProvider.providers.map { |key, provider| [ key, _(provider) ] }
  end

  def template_input_types_options
    TemplateInput::TYPES.map { |key, name| [ _(name), key ] }
  end

  def job_invocation_chart(bulk_task)
    options = { :class => "statistics-pie small", :expandable => true, :'border' => 0, :show_title => true }

    success = bulk_task.output['success_count']
    failed = bulk_task.output['failed_count']
    pending = bulk_task.output['total_count'] - failed - success

    flot_pie_chart("status", job_invocation_status(@job_invocation) + ' ' + (@job_invocation.last_task.progress * 100).to_i.to_s + '%', [
                             {:label => _('Success'), :data => success, :color => '#18AC05'},
                             {:label => _('Failed'), :data => failed, :color => '#AF0011'},
                             {:label => _('Pending'), :data => pending, :color => '#DEDEDE'},
                           ], options)
  end

  def job_invocation_status(invocation)
    invocation.last_task.pending ? _('Running') : _('Finished')
  end

  def host_counter(label, count)
    content_tag(:div, :class => 'host_counter') do
      content_tag(:div, label, :class => 'header') + content_tag(:div, count.to_s, :class => 'count')
    end
  end
end
