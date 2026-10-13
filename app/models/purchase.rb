class Purchase < ApplicationRecord
  belongs_to :item

  normalizes :receipt_name, with: ->(receipt_name) { receipt_name.squish }

  validates :purchased_on, presence: true
  validates :receipt_name, presence: true
end
