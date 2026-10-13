class Purchase < ApplicationRecord
  belongs_to :item

  validates :purchased_on, presence: true
  validates :receipt_name, presence: true
end
