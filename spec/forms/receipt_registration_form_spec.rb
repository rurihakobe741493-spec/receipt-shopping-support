require "rails_helper"

RSpec.describe ReceiptRegistrationForm do
  describe "#purchased_dates_by_item_id" do
    # 今日を 2026-10-30 にする。購入日として受け付ける範囲は 2025-10-31〜2026-10-30
    around do |example|
      travel_to(Date.new(2026, 10, 30)) { example.run }
    end

    def purchased_dates(user)
      described_class.new(user:).purchased_dates_by_item_id
    end

    it "範囲の始まりの日（1年前の同じ日の翌日）の購入日は入る" do
      item = create(:item)
      create(:purchase, item:, purchased_on: Date.new(2025, 10, 31))
      expect(purchased_dates(item.user)).to eq({ item.id.to_s => [ "2025-10-31" ] })
    end

    it "範囲の始まりの前日の購入日は入らない" do
      item = create(:item)
      build(:purchase, item:, purchased_on: Date.new(2025, 10, 30)).save!(validate: false)
      expect(purchased_dates(item.user)).to eq({})
    end

    it "今日の購入日は入る" do
      item = create(:item)
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 30))
      expect(purchased_dates(item.user)).to eq({ item.id.to_s => [ "2026-10-30" ] })
    end

    it "同じ日の購入記録が2件あっても、日付は1つにまとめ、古い順に並べる" do
      item = create(:item)
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 1))
      create(:purchase, item:, purchased_on: Date.new(2026, 9, 7))
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 1))
      expect(purchased_dates(item.user)).to eq({ item.id.to_s => [ "2026-09-07", "2026-10-01" ] })
    end

    it "購入記録のない品目は入らない" do
      item = create(:item)
      create(:item, user: item.user)
      create(:purchase, item:, purchased_on: Date.new(2026, 10, 1))
      expect(purchased_dates(item.user).keys).to eq([ item.id.to_s ])
    end

    it "ほかのユーザーの品目の購入日は入らない" do
      item = create(:item)
      other_user_item = create(:item)
      create(:purchase, item: other_user_item, purchased_on: Date.new(2026, 10, 1))
      expect(purchased_dates(item.user)).to eq({})
    end
  end
end
