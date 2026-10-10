require "rails_helper"

RSpec.describe ReceiptTextParser do
  around do |example|
    travel_to(Date.new(2026, 10, 10)) { example.run }
  end

  describe "#purchased_on" do
    def purchased_on(text)
      described_class.new(text).purchased_on
    end

    context "日付の表記" do
      it "月日が0埋めのとき、その日付を返す" do
        expect(purchased_on("2026年09月01日")).to eq(Date.new(2026, 9, 1))
      end

      it "月日が0埋めでないとき、その日付を返す" do
        expect(purchased_on("2026年9月1日")).to eq(Date.new(2026, 9, 1))
      end

      it "年のあとに空白があるとき、その日付を返す" do
        expect(purchased_on("2026年 09月01日")).to eq(Date.new(2026, 9, 1))
      end

      it "年・月・日の文字の前後に空白があるとき、その日付を返す" do
        expect(purchased_on("2026 年 9 月 1 日")).to eq(Date.new(2026, 9, 1))
      end
    end

    context "範囲" do
      it "今日は候補にする" do
        expect(purchased_on("2026年10月10日")).to eq(Date.new(2026, 10, 10))
      end

      it "明日は nil を返す" do
        expect(purchased_on("2026年10月11日")).to be_nil
      end

      it "1年前の翌日は候補にする" do
        expect(purchased_on("2025年10月11日")).to eq(Date.new(2025, 10, 11))
      end

      it "1年前の同じ日は nil を返す" do
        expect(purchased_on("2025年10月10日")).to be_nil
      end
    end

    context "ありえない日付" do
      it "2月30日は nil を返す" do
        expect(purchased_on("2026年02月30日")).to be_nil
      end

      it "13月は nil を返す" do
        expect(purchased_on("2026年13月01日")).to be_nil
      end
    end

    context "日付の行の選び方" do
      it "最初の日付の行が範囲外なら、あとの行に範囲の中の日付があっても nil を返す" do
        expect(purchased_on("2006年09月01日\n2026年09月01日")).to be_nil
      end

      it "レシートの全文では、最初の日付の行から購入日を返す" do
        text = <<~TEXT
          サンプル商店
          2026年10月03日 (土) 12時00分
          せっけん
          ¥198
          小計 ¥198
          クーポン有効期限 2026年12月31日
        TEXT

        expect(purchased_on(text)).to eq(Date.new(2026, 10, 3))
      end
    end

    context "日付がないとき" do
      it "日付の形の行がなければ nil を返す" do
        expect(purchased_on("サンプル商店\nせっけん")).to be_nil
      end

      it "全文が空なら nil を返す" do
        expect(purchased_on("")).to be_nil
      end
    end
  end
end
