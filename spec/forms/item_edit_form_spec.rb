require "rails_helper"

RSpec.describe ItemEditForm do
  # 品目の保存値の周期は30（DB の初期値）。画面に出していた周期は24（購入履歴から計算した値）として送る
  def edit_form(item, **attributes)
    described_class.new({ item:, name: item.name, cycle_days: "24", displayed_cycle_days: "24" }.merge(attributes))
  end

  describe ".from_item" do
    it "周期の欄と隠した欄の初期値は、計算した周期" do
      item = build(:item)
      [ Date.new(2026, 9, 7), Date.new(2026, 10, 1), Date.new(2026, 10, 25) ].each { |date| item.purchases.build(purchased_on: date) }
      form = described_class.from_item(item)
      expect([ form.name, form.cycle_days, form.displayed_cycle_days ]).to eq([ item.name, 24, 24 ])
    end
  end

  describe "#cycle_changed?" do
    it "周期が、画面に出していた周期と同じなら false を返す" do
      expect(edit_form(build(:item)).cycle_changed?).to be(false)
    end

    it "周期が、画面に出していた周期と違えば true を返す" do
      expect(edit_form(build(:item), cycle_days: "14").cycle_changed?).to be(true)
    end
  end

  describe "#save" do
    around do |example|
      travel_to(Date.new(2026, 10, 30)) { example.run }
    end

    it "品目名だけ直すと、品目名だけが変わり、周期と変更日はそのまま" do
      item = create(:item, name: "ティッシュ")
      expect(edit_form(item, name: "箱ティッシュ").save).to be(true)
      item.reload
      expect([ item.name, item.cycle_days, item.cycle_changed_on ]).to eq([ "箱ティッシュ", 30, nil ])
    end

    it "画面に出していた周期と違う数にすると、周期を変え、今日を変更日にする" do
      item = create(:item)
      expect(edit_form(item, cycle_days: "14").save).to be(true)
      item.reload
      expect([ item.cycle_days, item.cycle_changed_on ]).to eq([ 14, Date.new(2026, 10, 30) ])
    end

    it "保存値と同じ数でも、画面に出していた周期と違えば、周期を変えたとみなす" do
      item = create(:item)
      expect(edit_form(item, cycle_days: "30").save).to be(true)
      expect(item.reload.cycle_changed_on).to eq(Date.new(2026, 10, 30))
    end

    it "画面に出していた周期が365を超えていても、周期を変えなければ保存できる" do
      item = create(:item)
      expect(edit_form(item, name: "浄水器のカートリッジ", cycle_days: "400", displayed_cycle_days: "400").save).to be(true)
      expect(item.reload.cycle_days).to eq(30)
    end

    it "周期が範囲の外（366）なら保存せず、周期のエラーにする" do
      item = create(:item)
      form = edit_form(item, cycle_days: "366")
      expect(form.save).to be(false)
      expect(form.errors).to be_of_kind(:cycle_days, :less_than_or_equal_to)
      expect(item.reload.cycle_changed_on).to be_nil
    end

    it "同じユーザーのほかの品目と同じ名前なら保存せず、品目名のエラーにする" do
      item = create(:item)
      create(:item, user: item.user, name: "ティッシュ")
      form = edit_form(item, name: "ティッシュ")
      expect(form.save).to be(false)
      expect(form.errors).to be_of_kind(:name, :taken)
    end

    it "ほかのユーザーの品目と同じ名前なら保存できる" do
      item = create(:item)
      create(:item, name: "ティッシュ")
      expect(edit_form(item, name: "ティッシュ").save).to be(true)
    end

    it "検証のあとに、同じ名前がほかで保存されて DB で止まったら、品目名の重複のエラーにする" do
      item = create(:item)
      form = edit_form(item, name: "ティッシュ")
      # 2つのタブで同時に保存したときのように、検証は通り、保存のときに DB のユニークインデックスで止まる
      allow(item).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)
      expect(form.save).to be(false)
      expect(form.errors).to be_of_kind(:name, :taken)
    end
  end
end
