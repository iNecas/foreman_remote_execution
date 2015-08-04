class TemplateInvocationInputValue < ActiveRecord::Base

  belongs_to :template_invocation
  belongs_to :template_input

  validates :value, :presence => true, :if => Proc.new { |v| v.template_input.required? }

end