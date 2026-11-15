require "rails_helper"

RSpec.describe GuestUserCreator do
  around do |example|
    travel_to(Time.zone.local(2026, 11, 15, 12, 0, 0)) { example.run }
  end

  def names_and_days_left(estimates)
    estimates.map { |estimate| [ estimate.item.name, estimate.days_left ] }
  end

  describe ".call" do
    it "ゲストの印を付けたユーザーを、ゲストの形のメールアドレスで作る" do
      user = GuestUserCreator.call

      expect(user).to be_persisted
      expect(user.guest).to be true
      expect(user.email).to match(/\Aguest-[0-9a-f-]{36}@example\.com\z/)
    end

    it "見本の品目を3つ、購入記録を6件作る" do
      user = GuestUserCreator.call

      expect(user.items.count).to eq 3
      expect(Purchase.where(item: user.items).count).to eq 6
    end

    it "見本の品目が、目安を過ぎた・もうすぐ・まだ先に1つずつ分かれる" do
      stock_list = StockList.new(GuestUserCreator.call.items)

      expect(names_and_days_left(stock_list.overdue)).to eq [ [ "トイレットペーパー", -10 ] ]
      expect(names_and_days_left(stock_list.running_low)).to eq [ [ "洗濯洗剤", 5 ] ]
      expect(names_and_days_left(stock_list.others)).to eq [ [ "歯みがき粉", 25 ] ]
    end

    it "残しておく時間を過ぎたゲストを品目ごと消し、時間内のゲストとふつうのユーザーは残す" do
      expired_guest = create(:user, guest: true, created_at: 25.hours.ago)
      expired_item = create(:item, user: expired_guest)
      recent_guest = create(:user, guest: true, created_at: 23.hours.ago)
      old_user = create(:user, created_at: 30.days.ago)

      GuestUserCreator.call

      expect(User.exists?(expired_guest.id)).to be false
      expect(Item.exists?(expired_item.id)).to be false
      expect(User.exists?(recent_guest.id)).to be true
      expect(User.exists?(old_user.id)).to be true
    end
  end
end
