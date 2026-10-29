class Purchase < ApplicationRecord
  MAX_AGE = 1.year

  belongs_to :item

  normalizes :receipt_name, with: ->(receipt_name) { receipt_name.squish }

  validates :purchased_on, presence: true
  validates :receipt_name, presence: true
  validate :purchased_on_must_be_within_range

  # 購入日として受け付ける範囲（1年前の同じ日の翌日〜今日）
  # パーサーの購入日の候補と、確認画面の購入日の欄の min・max も、この範囲を使う
  def self.purchased_on_range
    today = Date.current
    (today - MAX_AGE + 1)..today
  end

  private

    def purchased_on_must_be_within_range
      return if purchased_on.blank?

      errors.add(:purchased_on, :out_of_range) unless self.class.purchased_on_range.cover?(purchased_on)
    end
end
