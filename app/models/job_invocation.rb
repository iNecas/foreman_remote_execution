class JobInvocation < ActiveRecord::Base

  belongs_to :targeting, :dependent => :destroy
  has_many :template_invocations, :inverse_of => :job_invocation, :dependent => :destroy

  validates :targeting, :presence => true
  validates :job_name, :presence => true

  def execution_type
    @execution_type || :now
  end

  def execution_type=(value)
    return @execution_type if @execution_type
    if [:now, :future].map(&:to_s).include?(value)
      @execution_type = value.to_sym
    end
  end

  def start_at_parsed
    @start_at.present? && Time.strptime(@start_at, time_format)
  end

  def start_at
    @start_at ||= Time.now.strftime(time_format)
  end

  def start_at=(value)
    @start_at = value
  end

  def time_format
    '%Y-%m-%d %H:%M'
  end
end
