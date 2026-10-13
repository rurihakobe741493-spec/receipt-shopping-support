FactoryBot.define do
  factory :purchase do
    item { nil }
    purchased_on { "2026-10-13" }
    receipt_name { "MyString" }
  end
end
