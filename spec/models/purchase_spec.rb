require "rails_helper"

RSpec.describe Purchase, type: :model do
  it "ファクトリーのデータは有効" do
    expect(build(:purchase)).to be_valid
  end

  describe "品目" do
    it "ないと無効" do
      purchase = build(:purchase, item: nil)
      purchase.valid?
      expect(purchase.errors).to be_of_kind(:item, :blank)
    end
  end

  describe "購入日" do
    it "空なら無効" do
      purchase = build(:purchase, purchased_on: "")
      purchase.valid?
      expect(purchase.errors).to be_of_kind(:purchased_on, :blank)
    end

    it "同じ品目・同じ日の購入記録を、2件保存できる" do
      purchase = create(:purchase)
      same_day_purchase = create(:purchase, item: purchase.item, purchased_on: purchase.purchased_on)
      expect(same_day_purchase).to be_persisted
    end
  end

  describe "レシート表記" do
    it "空なら無効" do
      purchase = build(:purchase, receipt_name: "")
      purchase.valid?
      expect(purchase.errors).to be_of_kind(:receipt_name, :blank)
    end

    it "全角の空白だけなら無効" do
      purchase = build(:purchase, receipt_name: "　")
      purchase.valid?
      expect(purchase.errors).to be_of_kind(:receipt_name, :blank)
    end

    it "前後・途中の空白を整える" do
      purchase = build(:purchase, receipt_name: "　ティッシュ　 5箱 ")
      expect(purchase.receipt_name).to eq("ティッシュ 5箱")
    end
  end
end
