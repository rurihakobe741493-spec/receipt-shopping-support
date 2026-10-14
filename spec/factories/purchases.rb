FactoryBot.define do
  factory :purchase do
    association :item
    purchased_on { Date.current }
    receipt_name { "サンプル商品" }
  end
end
