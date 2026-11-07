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

  describe "#save" do
    # 今日を 2026-10-30 にする。購入日として受け付ける範囲は 2025-10-31〜2026-10-30
    around do |example|
      travel_to(Date.new(2026, 10, 30)) { example.run }
    end

    # 画面から届く形でフォームを作る。行は配列なら番号 0, 1, … を付け、ハッシュならその番号のまま使う（値はどれも文字列）
    def registration_form(user, rows, purchased_on: "2026-10-20")
      rows_attributes = rows.is_a?(Hash) ? rows : rows.each_with_index.to_h { |row, index| [ index.to_s, row ] }
      described_class.new(user:, purchased_on:, rows_attributes:)
    end

    # 既存の品目に紐付ける行
    def existing_row(item, receipt_name: "レシートの品名")
      { "selected" => "1", "receipt_name" => receipt_name, "item_id" => item.id.to_s }
    end

    # 新しい品目を作る行（「新規として登録」）
    def new_row(name, cycle_days: "30", receipt_name: "レシートの品名")
      { "selected" => "1", "receipt_name" => receipt_name, "item_id" => "new", "name" => name, "cycle_days" => cycle_days }
    end

    # 足した行のまま、何も入れていない行
    def empty_row(selected: "1")
      { "selected" => selected, "receipt_name" => "", "item_id" => "" }
    end

    context "既存の品目に紐付ける（#27）" do
      it "チェックした行を、選んだ品目の購入記録として保存する" do
        user = create(:user)
        item = create(:item, user:)
        other_item = create(:item, user:)
        form = registration_form(user, [ existing_row(item, receipt_name: "ティッシュ"), existing_row(other_item, receipt_name: "洗剤") ])
        expect(form.save).to be(true)
        expect(item.purchases.pluck(:purchased_on, :receipt_name)).to eq([ [ Date.new(2026, 10, 20), "ティッシュ" ] ])
        expect(other_item.purchases.pluck(:receipt_name)).to eq([ "洗剤" ])
        expect([ form.purchases_count, form.new_items_count ]).to eq([ 2, 0 ])
      end

      it "「選んでください」のままの行は、ストックのエラーにして、何も保存しない" do
        user = create(:user)
        form = registration_form(user, [ existing_row(create(:item, user:)), empty_row.merge("receipt_name" => "ティッシュ") ])
        expect(form.save).to be(false)
        expect(form.rows[1].errors).to be_of_kind(:item_id, :blank)
        expect(Purchase.count).to eq(0)
      end

      it "ほかのユーザーの品目の id は見つからず、ストックのエラーにする" do
        user = create(:user)
        form = registration_form(user, [ existing_row(create(:item)) ])
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:item_id, :blank)
        expect(Purchase.count).to eq(0)
      end

      it "チェックした行が0なら、フォームのエラーにする" do
        user = create(:user)
        form = registration_form(user, [ existing_row(create(:item, user:)).merge("selected" => "0") ])
        expect(form.save).to be(false)
        expect(form.errors).to be_of_kind(:base, :no_selected_rows)
      end

      it "購入日が範囲の始まりの前日なら、行が2つでも、購入日のエラーをフォームに1つだけ付ける" do
        user = create(:user)
        form = registration_form(user, [ existing_row(create(:item, user:)), existing_row(create(:item, user:)) ], purchased_on: "2025-10-30")
        expect(form.save).to be(false)
        expect(form.errors).to be_of_kind(:purchased_on, :out_of_range)
        expect(form.errors.where(:purchased_on).size).to eq(1)
      end

      it "購入日が明日なら、購入日のエラーにする" do
        user = create(:user)
        form = registration_form(user, [ existing_row(create(:item, user:)) ], purchased_on: "2026-10-31")
        expect(form.save).to be(false)
        expect(form.errors).to be_of_kind(:purchased_on, :out_of_range)
      end

      it "購入日が空なら、購入日のエラーにする" do
        user = create(:user)
        form = registration_form(user, [ existing_row(create(:item, user:)) ], purchased_on: "")
        expect(form.save).to be(false)
        expect(form.errors).to be_of_kind(:purchased_on, :blank)
      end

      it "行の文字列（レシート表記）が空なら、その行のエラーにする" do
        user = create(:user)
        form = registration_form(user, [ existing_row(create(:item, user:), receipt_name: "") ])
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:receipt_name, :blank)
      end

      it "チェックを外した行は、中身が空でも止めず、保存もしない" do
        user = create(:user)
        form = registration_form(user, [ existing_row(create(:item, user:)), empty_row(selected: "0") ])
        expect(form.save).to be(true)
        expect(Purchase.count).to eq(1)
      end

      it "検証のあとに品目が消えて途中で失敗したら、それまでの購入記録も残さず、登録できなかったエラーにする" do
        user = create(:user)
        item = create(:item, user:)
        deleted_item = create(:item, user:)
        form = registration_form(user, [ existing_row(item), existing_row(deleted_item) ])
        expect(form).to be_valid
        deleted_item.destroy
        expect(form.save).to be(false)
        expect(form.errors).to be_of_kind(:base, :save_failed)
        expect(Purchase.count).to eq(0)
      end
    end

    context "新しい品目を作る（#28）" do
      it "「新規として登録」の行は、品目名と周期で品目を作り、その購入記録を保存する" do
        user = create(:user)
        form = registration_form(user, [ new_row("ティッシュ", cycle_days: "14") ])
        expect(form.save).to be(true)
        expect(user.items.pluck(:name, :cycle_days)).to eq([ [ "ティッシュ", 14 ] ])
        expect(Purchase.count).to eq(1)
        expect([ form.purchases_count, form.new_items_count ]).to eq([ 1, 1 ])
      end

      it "新規と既存の行が混ざっていても、どちらも保存する" do
        user = create(:user)
        form = registration_form(user, [ existing_row(create(:item, user:)), new_row("ティッシュ") ])
        expect(form.save).to be(true)
        expect(Item.count).to eq(2)
        expect(Purchase.count).to eq(2)
      end

      it "周期は1と365なら作れる" do
        user = create(:user)
        expect(registration_form(user, [ new_row("ティッシュ", cycle_days: "1"), new_row("洗剤", cycle_days: "365") ]).save).to be(true)
      end

      it "周期が空なら、その行の周期のエラーにする" do
        form = registration_form(create(:user), [ new_row("ティッシュ", cycle_days: "") ])
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:cycle_days, :not_a_number)
      end

      it "周期が0なら、その行の周期のエラーにする" do
        form = registration_form(create(:user), [ new_row("ティッシュ", cycle_days: "0") ])
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:cycle_days, :greater_than_or_equal_to)
      end

      it "周期が 1.5 なら、1 に丸めず、その行の周期のエラーにする" do
        form = registration_form(create(:user), [ new_row("ティッシュ", cycle_days: "1.5") ])
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:cycle_days, :not_an_integer)
      end

      it "周期が366なら、その行の周期のエラーにする" do
        form = registration_form(create(:user), [ new_row("ティッシュ", cycle_days: "366") ])
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:cycle_days, :less_than_or_equal_to)
      end

      it "周期が30億（DB の整数に入らない大きさ）でも、保存の前にその行の周期のエラーにする" do
        form = registration_form(create(:user), [ new_row("ティッシュ", cycle_days: "3000000000") ])
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:cycle_days, :less_than_or_equal_to)
      end

      it "品目名が空なら、その行の品目名のエラーにする" do
        form = registration_form(create(:user), [ new_row("") ])
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:name, :blank)
      end

      it "品目名が全角の空白だけなら、その行の品目名のエラーにする" do
        form = registration_form(create(:user), [ new_row("　") ])
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:name, :blank)
      end

      it "保存済みの品目と同じ名前なら、ストックから選ぶ案内のエラーにする" do
        user = create(:user)
        create(:item, user:, name: "ティッシュ")
        form = registration_form(user, [ new_row("ティッシュ") ])
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:name, :same_as_registered_item)
      end

      it "新規の行どうしで、前後の空白を整えると同じ名前なら、両方の行のエラーにする" do
        form = registration_form(create(:user), [ new_row("ティッシュ"), new_row(" ティッシュ ") ])
        expect(form.save).to be(false)
        expect(form.rows.map { |row| row.errors.of_kind?(:name, :same_as_other_new_row) }).to eq([ true, true ])
      end

      it "2行とも保存済みの品目と同じ名前なら、保存済みと同じというエラーだけにする" do
        user = create(:user)
        create(:item, user:, name: "ティッシュ")
        form = registration_form(user, [ new_row("ティッシュ"), new_row("ティッシュ") ])
        expect(form.save).to be(false)
        expect(form.rows.map { |row| row.errors.of_kind?(:name, :same_as_registered_item) }).to eq([ true, true ])
        expect(form.rows.map { |row| row.errors.of_kind?(:name, :same_as_other_new_row) }).to eq([ false, false ])
      end

      it "全角カナと半角カナだけが違う名前は、別の品目として作る" do
        form = registration_form(create(:user), [ new_row("ティッシュ"), new_row("ﾃｨｯｼｭ") ])
        expect(form.save).to be(true)
        expect(Item.count).to eq(2)
      end

      it "ほかのユーザーの品目と同じ名前でも作れる" do
        create(:item, name: "ティッシュ")
        form = registration_form(create(:user), [ new_row("ティッシュ") ])
        expect(form.save).to be(true)
      end

      it "既存の品目を選んだ行に届いた品目名と周期は、読まない" do
        user = create(:user)
        item = create(:item, user:, name: "ティッシュ")
        form = registration_form(user, [ existing_row(item).merge("name" => "書き換えた名前", "cycle_days" => "0") ])
        expect(form.save).to be(true)
        expect(Item.count).to eq(1)
        expect(item.reload.attributes.values_at("name", "cycle_days")).to eq([ "ティッシュ", 30 ])
      end
    end

    context "足した行（#51）" do
      it "13桁の番号の足した行も、既存・新規とも保存する" do
        user = create(:user)
        form = registration_form(user, { "0" => existing_row(create(:item, user:)), "1730000000000" => new_row("ティッシュ") })
        expect(form.save).to be(true)
        expect(Purchase.count).to eq(2)
      end

      it "番号が飛んでいても保存する" do
        user = create(:user)
        form = registration_form(user, { "0" => existing_row(create(:item, user:)), "5" => existing_row(create(:item, user:)) })
        expect(form.save).to be(true)
        expect(Purchase.count).to eq(2)
      end

      it "何も入れていない足した行は、チェックがあれば、レシート表記とストックのエラーにする" do
        user = create(:user)
        form = registration_form(user, { "0" => existing_row(create(:item, user:)), "1730000000000" => empty_row })
        expect(form.save).to be(false)
        expect(form.rows[1].errors).to be_of_kind(:receipt_name, :blank)
        expect(form.rows[1].errors).to be_of_kind(:item_id, :blank)
      end

      it "何も入れていない足した行は、チェックがなければ、止めずに保存しない" do
        user = create(:user)
        form = registration_form(user, { "0" => existing_row(create(:item, user:)), "1730000000000" => empty_row(selected: "0") })
        expect(form.save).to be(true)
        expect(Purchase.count).to eq(1)
      end

      it "新規の行で、レシート表記と品目名が空なら、それぞれのエラーを1つずつ付ける" do
        form = registration_form(create(:user), { "1730000000000" => new_row("", receipt_name: "") })
        expect(form.save).to be(false)
        expect(form.rows[0].errors).to be_of_kind(:receipt_name, :blank)
        expect(form.rows[0].errors).to be_of_kind(:name, :blank)
        expect([ form.rows[0].errors.where(:receipt_name).size, form.rows[0].errors.where(:name).size ]).to eq([ 1, 1 ])
      end

      it "読み取った行の新規と、足した行の新規が同じ名前なら、両方の行のエラーにする" do
        form = registration_form(create(:user), { "0" => new_row("ティッシュ"), "1730000000000" => new_row("ティッシュ") })
        expect(form.save).to be(false)
        expect(form.rows.map { |row| row.errors.of_kind?(:name, :same_as_other_new_row) }).to eq([ true, true ])
      end

      it "行は、送られた順のまま並べる（足した行は最後）" do
        form = registration_form(create(:user), { "0" => new_row("A", receipt_name: "1行目"), "1" => new_row("B", receipt_name: "2行目"), "1730000000000" => new_row("C", receipt_name: "足した行") })
        expect(form.rows.map(&:receipt_name)).to eq([ "1行目", "2行目", "足した行" ])
      end
    end
  end
end
