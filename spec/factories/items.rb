FactoryBot.define do
  factory :item do
    user { nil }
    name { "MyString" }
    cycle_days { 1 }
    cycle_changed_on { "2026-10-13" }
  end
end
