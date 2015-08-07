class JobInvocationsController < ApplicationController
  def new
    @composer = JobInvocationComposer.new(JobInvocation.new,
                                          :host_ids => params[:host_ids],
                                          :targeting => {
                                            :targeting_type => Targeting::STATIC_TYPE,
                                            :bookmark_id => params[:bookmark_id]
                                          })
  end

  def create
    @composer = JobInvocationComposer.new(JobInvocation.new, params)
    if @composer.save
      job_invocation = @composer.job_invocation
      if job_invocation.execution_type == :future
        t = ForemanTasks.dynflow.world.schedule(::Actions::RemoteExecution::JobRun, {start_at: job_invocation.start_at_parsed}, job_invocation)
        @task = ForemanTasks::Task.find_by_external_id(t.id)
      else
        @task = ForemanTasks.async_task(::Actions::RemoteExecution::JobRun, job_invocation)
      end
      redirect_to foreman_tasks_task_path(@task)
    else
      render :action => 'new'
    end
  end

  def show
    # TODO authorization
    @job_invocation = JobInvocation.find(params[:id])
  end

  def apply
    @job_invocation = JobInvocation.find(params[:id])
    @task = ForemanTasks.async_task(::Actions::RemoteExecution::JobRun, @job_invocation)
    redirect_to foreman_tasks_task_path(@task)
  end

  # refreshes the form
  def refresh
    @composer = JobInvocationComposer.new(JobInvocation.new, params)
  end
end
