class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  RANSACKABLE_EXCLUDED_ATTRIBUTES = %w[
    encrypted_password
    password_reset_token
    reset_password_token
  ].freeze

  def self.ransackable_attributes(_auth_object = nil)
    column_names - RANSACKABLE_EXCLUDED_ATTRIBUTES
  end

  def self.ransackable_associations(_auth_object = nil)
    reflect_on_all_associations.map { |association| association.name.to_s }
  end
end
