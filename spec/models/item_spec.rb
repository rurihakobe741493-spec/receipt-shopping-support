require "rails_helper"

RSpec.describe Item, type: :model do
  it "ファクトリーのデータは有効" do
    expect(build(:item)).to be_valid
  end

  describe "ユーザー" do
    it "ないと無効" do
      item = build(:item, user: nil)
      item.valid?
      expect(item.errors).to be_of_kind(:user, :blank)
    end
  end

  describe "品目名" do
    it "空なら無効" do
      item = build(:item, name: "")
      item.valid?
      expect(item.errors).to be_of_kind(:name, :blank)
    end

    it "全角の空白だけなら無効" do
      item = build(:item, name: "　")
      item.valid?
      expect(item.errors).to be_of_kind(:name, :blank)
    end

    it "前後の半角・全角の空白を除く" do
      item = build(:item, name: "　ティッシュ ")
      expect(item.name).to eq("ティッシュ")
    end

    it "途中の続いた空白を、半角1つにまとめる" do
      item = build(:item, name: "トイレット　 ペーパー")
      expect(item.name).to eq ("トイレット ペーパー")
    end

    it "同じユーザーの登録済みの品目名と同じなら無効" do
      item = create(:item, name: "ティッシュ")
      duplicated_item = build(:item, user: item.user, name: "ティッシュ")
      duplicated_item.valid?
      expect(duplicated_item.errors).to be_of_kind(:name, :taken)
    end

    it "空白を整えたあとの値で、登録済みの品目名と比べる" do
      item = create(:item, name: "ティッシュ")
      duplicated_item = build(:item, user: item.user, name: "　ティッシュ ")
      duplicated_item.valid?
      expect(duplicated_item.errors).to be_of_kind(:name, :taken)
    end

    it "別のユーザーの品目名と同じなら有効" do
      create(:item, name: "ティッシュ")
      other_user_item = build(:item, name: "ティッシュ")
      expect(other_user_item).to be_valid
    end

    it "検証を通さずに同じ品目名を保存すると、DBの制約で例外になる" do
      item = create(:item, name: "ティッシュ")
      duplicated_item = build(:item, user: item.user, name: "ティッシュ")
      expect { duplicated_item.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect(Item.count).to eq(1)
    end
  end

  describe "周期" do
    it "初期値は30" do
      expect(Item.new.cycle_days).to eq(30)
    end

    it "空なら無効" do
      item = build(:item, cycle_days: "")
      item.valid?
      expect(item.errors).to be_of_kind(:cycle_days, :not_a_number)
    end

    it "文字なら無効" do
      item = build(:item, cycle_days: "abc")
      item.valid?
      expect(item.errors).to be_of_kind(:cycle_days, :not_a_number)
    end

    it "小数なら無効" do
      item = build(:item, cycle_days: "1.5")
      item.valid?
      expect(item.errors).to be_of_kind(:cycle_days, :not_an_integer)
    end

    it "0なら無効" do
      item = build(:item, cycle_days: "0")
      item.valid?
      expect(item.errors).to be_of_kind(:cycle_days, :greater_than_or_equal_to)
    end

    it "1なら有効" do
      expect(build(:item, cycle_days: "1")).to be_valid
    end
  end

  describe "削除" do
    it "品目を削除すると、その購入記録も削除される" do
      purchase = create(:purchase)
      expect { purchase.item.destroy }.to change(Purchase, :count).by(-1)
    end
  end
end
