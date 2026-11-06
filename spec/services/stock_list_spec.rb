require "rails_helper"

RSpec.describe StockList do
  around do |example|
    travel_to(Date.new(2026, 10, 30)) { example.run }
  end

  let(:user) { create(:user) }
  let(:stock_list) { StockList.new(user.items) }

  # 品目を作り、購入日を渡したときは、その日の購入記録を1件足す（周期はファクトリーのまま30日）
  def create_item(user, name, purchased_on = nil)
    item = create(:item, user:, name:)
    create(:purchase, item:, purchased_on:) if purchased_on
    item
  end

  def names(estimates)
    estimates.map { |estimate| estimate.item.name }
  end

  # ブロックの中で流れた SQL の数（スキーマを読むものは数えない）
  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  describe "並びと振り分け" do
    before do
      # 作る順は、並ぶ順と変えておく
      create_item(user, "まな板")                              # 購入記録なし
      create_item(user, "歯ブラシ", Date.new(2026, 10, 20))    # 残り20日
      create_item(user, "スポンジ", Date.new(2026, 10, 8))     # 残り8日
      create_item(user, "ゴミ袋", Date.new(2026, 10, 8))       # 残り8日（スポンジと同じ）
      create_item(user, "洗剤", Date.new(2026, 10, 7))         # 残り7日
      create_item(user, "シャンプー", Date.new(2026, 10, 1))   # 残り1日
      create_item(user, "ティッシュ", Date.new(2026, 9, 30))   # 残り0日
      create_item(user, "牛乳", Date.new(2026, 9, 29))         # 残り-1日
      create_item(user, "電池", Date.new(2026, 9, 20))         # 残り-10日
    end

    it "目安を過ぎた品目を、残り日数の少ない順に overdue に入れる" do
      expect(names(stock_list.overdue)).to eq([ "電池", "牛乳" ])
    end

    it "残り0〜7日の品目を、残り日数の少ない順に running_low に入れる" do
      expect(names(stock_list.running_low)).to eq([ "ティッシュ", "シャンプー", "洗剤" ])
    end

    it "どちらの枠にも入らない品目を others に入れ、残り日数が同じなら品目名の順、購入記録なしは最後に並べる" do
      expect(names(stock_list.others)).to eq([ "ゴミ袋", "スポンジ", "歯ブラシ", "まな板" ])
    end

    it "品目があれば、empty? は false を返す" do
      expect(stock_list.empty?).to be(false)
    end
  end

  it "品目が0件なら、empty? は true を返し、3つとも空にする" do
    expect(stock_list.empty?).to be(true)
    expect([ stock_list.overdue, stock_list.running_low, stock_list.others ]).to all(be_empty)
  end

  it "作るときの SQL は品目と購入記録の2回で、品目の数によらず、振り分けでは SQL を出さない" do
    create_item(user, "電池", Date.new(2026, 9, 20))
    create_item(user, "洗剤", Date.new(2026, 10, 7))
    create_item(user, "まな板")
    list = nil

    expect(count_queries { list = StockList.new(user.items) }).to eq(2)
    expect(count_queries { [ list.empty?, list.overdue, list.running_low, list.others ] }).to eq(0)
  end
end
