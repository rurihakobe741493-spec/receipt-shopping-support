class Item < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :cycle_days, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
end
