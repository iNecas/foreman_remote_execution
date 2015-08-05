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
      notice _('Job has been scheduled')
      redirect_to @composer.job_invocation
    else
      render :action => 'new'
    end
  end

  def show
    # TODO authorization
    @job_invocation = JobInvocation.find(params[:id])
  end

  # refreshes the form
  def refresh
    @composer = JobInvocationComposer.new(JobInvocation.new, params)
  end
end
