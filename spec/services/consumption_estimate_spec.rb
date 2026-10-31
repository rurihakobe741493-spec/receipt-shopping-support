require "rails_helper"

RSpec.describe ConsumptionEstimate do
  # 購入日（文字列で並べる）と品目の設定から、推定を作る。保存はしない
  def estimate(*dates, **item_attributes)
    item = build(:item, **item_attributes)
    dates.each { |date| item.purchases.build(purchased_on: date) }
    ConsumptionEstimate.new(item)
  end

  describe "#last_purchased_on" do
    it "購入記録が0件なら、nil を返す" do
      expect(estimate.last_purchased_on).to be_nil
    end

    it "作った順に関係なく、一番新しい購入日を返す" do
      expect(estimate("2026-10-01", "2026-09-01").last_purchased_on).to eq(Date.new(2026, 10, 1))
    end

    it "周期を変えた日より前の購入も含める" do
      expect(estimate("2026-10-01", "2026-10-20", cycle_days: 40, cycle_changed_on: "2026-10-25").last_purchased_on).to eq(Date.new(2026, 10, 20))
    end
  end

  describe "#cycle_days" do
    it "購入記録が0件なら、品目の周期を返す" do
      expect(estimate.cycle_days).to eq(30)
    end

    it "購入日が1日分なら、品目の周期を返す" do
      expect(estimate("2026-10-01").cycle_days).to eq(30)
    end

    it "品目の周期を変えていれば、その値を返す" do
      expect(estimate("2026-10-01", cycle_days: 40).cycle_days).to eq(40)
    end

    it "同じ日の購入が2件だけなら、1日分とみなして品目の周期を返す" do
      expect(estimate("2026-10-01", "2026-10-01").cycle_days).to eq(30)
    end

    it "購入日が2日分なら、その間隔を返す" do
      expect(estimate("2026-09-01", "2026-09-21").cycle_days).to eq(20)
    end

    it "購入日が3日分以上なら、間隔の平均を返す" do
      expect(estimate("2026-06-01", "2026-07-01", "2026-07-31", "2026-09-29").cycle_days).to eq(40)
    end

    it "同じ日の購入を1回とみなして、間隔の平均を出す" do
      expect(estimate("2026-09-01", "2026-09-01", "2026-10-01").cycle_days).to eq(30)
    end

    it "平均が割り切れないときは四捨五入する（59÷2 は 30）" do
      expect(estimate("2026-08-01", "2026-08-31", "2026-09-29").cycle_days).to eq(30)
    end

    it "平均が割り切れないときは四捨五入する（88÷3 は 29）" do
      expect(estimate("2026-06-01", "2026-06-26", "2026-07-31", "2026-08-28").cycle_days).to eq(29)
    end

    it "周期を整数で返す" do
      expect(estimate("2026-09-01", "2026-09-21").cycle_days).to be_an(Integer)
    end

    it "周期を変えた日の購入は、計算に含める" do
      expect(estimate("2026-09-01", "2026-10-01", "2026-10-21", cycle_days: 40, cycle_changed_on: "2026-10-01").cycle_days).to eq(20)
    end

    it "周期を変えた日の前日の購入は、計算に含めない" do
      expect(estimate("2026-09-01", "2026-10-01", "2026-10-21", cycle_days: 40, cycle_changed_on: "2026-10-02").cycle_days).to eq(40)
    end

    it "周期を変えたあとに購入がなければ、品目の周期を返す" do
      expect(estimate("2026-10-01", "2026-10-20", cycle_days: 40, cycle_changed_on: "2026-10-25").cycle_days).to eq(40)
    end
  end

  describe "#next_purchase_on" do
    it "購入記録が0件なら、nil を返す" do
      expect(estimate.next_purchase_on).to be_nil
    end

    it "最終購入日に周期を足した日を返す" do
      expect(estimate("2026-10-01", "2026-10-21").next_purchase_on).to eq(Date.new(2026, 11, 10))
    end

    it "周期を変えたあとに購入がなければ、最終購入日に品目の周期を足す" do
      expect(estimate("2026-10-01", "2026-10-20", cycle_days: 40, cycle_changed_on: "2026-10-25").next_purchase_on).to eq(Date.new(2026, 11, 29))
    end
  end

  describe "#days_left" do
    around do |example|
      travel_to(Date.new(2026, 10, 30)) { example.run }
    end

    it "購入記録が0件なら、nil を返す" do
      expect(estimate.days_left).to be_nil
    end

    it "今日から次回購入目安までの日数を返す" do
      expect(estimate("2026-10-01", "2026-10-21").days_left).to eq(11)
    end

    it "次回購入目安が今日なら、0 を返す" do
      expect(estimate("2026-10-10", "2026-10-20").days_left).to eq(0)
    end

    it "次回購入目安を過ぎていれば、マイナスの日数を返す" do
      expect(estimate("2026-10-07", "2026-10-17").days_left).to eq(-3)
    end

    it "残り日数を整数で返す" do
      expect(estimate("2026-10-01", "2026-10-21").days_left).to be_an(Integer)
    end
  end

  describe "#overdue?" do
    around do |example|
      travel_to(Date.new(2026, 10, 30)) { example.run }
    end

    it "購入記録が0件なら、false を返す" do
      expect(estimate.overdue?).to be(false)
    end

    it "残り日数が-1なら、true を返す" do
      expect(estimate("2026-09-29").overdue?).to be(true)
    end

    it "残り日数が0なら、false を返す" do
      expect(estimate("2026-09-30").overdue?).to be(false)
    end
  end

  describe "#running_low?" do
    around do |example|
      travel_to(Date.new(2026, 10, 30)) { example.run }
    end

    it "購入記録が0件なら、false を返す" do
      expect(estimate.running_low?).to be(false)
    end

    it "残り日数が-1なら、false を返す" do
      expect(estimate("2026-09-29").running_low?).to be(false)
    end

    it "残り日数が0なら、true を返す" do
      expect(estimate("2026-09-30").running_low?).to be(true)
    end

    it "残り日数が7なら、true を返す" do
      expect(estimate("2026-10-07").running_low?).to be(true)
    end

    it "残り日数が8なら、false を返す" do
      expect(estimate("2026-10-08").running_low?).to be(false)
    end
  end
end
