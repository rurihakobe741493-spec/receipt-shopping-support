class Item < ApplicationRecord
  # エラーの文（ja.yml の item.cycle_days.out_of_range）にも、同じ数字を書いている
  MAX_CYCLE_DAYS = 365

  belongs_to :user
  has_many :purchases, dependent: :destroy

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :cycle_days, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: MAX_CYCLE_DAYS,
    message: :out_of_range
  }
end
