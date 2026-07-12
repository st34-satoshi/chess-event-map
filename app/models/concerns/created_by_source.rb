module CreatedBySource
  extend ActiveSupport::Concern

  included do
    enum :created_by, { human: "human", ai: "ai" }, default: "human"
  end
end
