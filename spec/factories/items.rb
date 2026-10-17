FactoryBot.define do
  factory :item do
    association :user
    sequence(:name) { |n| "品目#{n}" }
  end
end
