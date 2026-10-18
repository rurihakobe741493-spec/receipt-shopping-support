require "rails_helper"

RSpec.describe ReceiptTextParser do
  describe "#purchased_on" do
    around do |example|
      travel_to(Date.new(2026, 10, 10)) { example.run }
    end

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

      it "スラッシュで年が4桁のとき、その日付を返す" do
        expect(purchased_on("2026/09/01")).to eq(Date.new(2026, 9, 1))
      end

      it "スラッシュで年が2桁のとき、2000年代の日付を返す" do
        expect(purchased_on("26/09/01")).to eq(Date.new(2026, 9, 1))
      end

      it "スラッシュで月日が0埋めでないとき、その日付を返す" do
        expect(purchased_on("26/9/1")).to eq(Date.new(2026, 9, 1))
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

      it "スラッシュの13月は nil を返す" do
        expect(purchased_on("26/13/01")).to be_nil
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

      it "スラッシュの日付の行が先にあれば、その行から購入日を返す" do
        expect(purchased_on("2026/09/01\n2026年09月02日")).to eq(Date.new(2026, 9, 1))
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

  describe "#item_lines" do
    def item_lines(text)
      described_class.new(text).item_lines
    end

    context "範囲" do
      it "日付の行の次から、小計の行の前までを返す" do
        text = <<~TEXT
          サンプル商店
          2026年10月1日 (木) 12:00
          サンプル牛乳
          サンプル洗剤
          小計 ¥300
          サンプル会員様
        TEXT

        expect(item_lines(text)).to eq([ "サンプル牛乳", "サンプル洗剤" ])
      end

      it "日付が先頭の行なら、2行目から返す" do
        expect(item_lines("2026年10月1日\nサンプル牛乳\n小計 ¥100")).to eq([ "サンプル牛乳" ])
      end

      it "スラッシュの日付の行の次から返す" do
        expect(item_lines("サンプル商店\n26/10/01\nサンプル牛乳\n小計 ¥100")).to eq([ "サンプル牛乳" ])
      end

      it "日付の行がなければ、先頭から返す" do
        expect(item_lines("サンプル商店\nサンプル牛乳\n小計 ¥100")).to eq([ "サンプル商店", "サンプル牛乳" ])
      end

      it "小計の行がなければ、最初の合計の行の前までを返す" do
        expect(item_lines("2026年10月1日\nサンプル牛乳\n合計 ¥100\nサンプル会員様\n対象合計 ¥100")).to eq([ "サンプル牛乳" ])
      end

      it "小計も合計もなければ、最初の消費税の行の前までを返す" do
        expect(item_lines("2026年10月1日\nサンプル牛乳\n(内消費税\nサンプル会社")).to eq([ "サンプル牛乳" ])
      end

      it "小計も合計もなければ、最初の点数の行の前までを返す" do
        expect(item_lines("2026年10月1日\nサンプル牛乳\n( 1点)\nサンプル会社")).to eq([ "サンプル牛乳" ])
      end

      it "目印がどれもなければ、最後の行までを返す" do
        expect(item_lines("2026年10月1日\nサンプル牛乳\nサンプル会社")).to eq([ "サンプル牛乳", "サンプル会社" ])
      end

      it "小計の前にある合計の行は除く" do
        expect(item_lines("2026年10月1日\nサンプル牛乳\n合計\n小計 ¥100")).to eq([ "サンプル牛乳" ])
      end
    end

    context "範囲の終わりの見つけ方" do
      it "前に文字が付いた小計の行で終える" do
        expect(item_lines("2026年10月1日\nサンプル牛乳\n1点 小計 ¥100\nサンプル会員様")).to eq([ "サンプル牛乳" ])
      end

      it "文字の間に全角の空白がある小計の行で終える" do
        expect(item_lines("2026年10月1日\nサンプル牛乳\n小　計 ¥100\nサンプル会員様")).to eq([ "サンプル牛乳" ])
      end

      it "点数のあとに文字が続く行では終えない" do
        expect(item_lines("2026年10月1日\nサンプル靴下 3点セット\nサンプル牛乳\n( 2点)")).to eq([ "サンプル靴下 3点セット", "サンプル牛乳" ])
      end
    end

    context "除く行" do
      it "金額だけの行は除く（¥ の読み違え、カンマや空白の入ったものを含む）" do
        expect(item_lines("サンプル牛乳\n¥100\n\\1, 000\n#1,000")).to eq([ "サンプル牛乳" ])
      end

      it "金額と個数だけの行は除く" do
        expect(item_lines("サンプル牛乳\n¥100 2個\n(2個¥200")).to eq([ "サンプル牛乳" ])
      end

      it "かっこの付いた金額の行は除く" do
        expect(item_lines("サンプル牛乳\n¥10)")).to eq([ "サンプル牛乳" ])
      end

      it "数字だけの行は除く（金額・個数・JANコード）" do
        expect(item_lines("サンプル牛乳\n100\n2\n1234567890128")).to eq([ "サンプル牛乳" ])
      end

      it "数量の行は除く" do
        expect(item_lines("サンプル牛乳\n2コ x 単100\n¥100×2(外10)")).to eq([ "サンプル牛乳" ])
      end

      it "単価の行は除く" do
        expect(item_lines("サンプル牛乳\n@100 1")).to eq([ "サンプル牛乳" ])
      end

      it "割引の行は除く" do
        expect(item_lines("サンプル牛乳\n割引 10%")).to eq([ "サンプル牛乳" ])
      end

      it "マイナスで始まる値引きの行は除く" do
        expect(item_lines("サンプル牛乳\n-\\20")).to eq([ "サンプル牛乳" ])
      end

      it "まとめ買いの行は除く" do
        expect(item_lines("サンプル牛乳\n2個まとめ ¥180")).to eq([ "サンプル牛乳" ])
      end

      it "文字も数字もない行は除く" do
        expect(item_lines("サンプル牛乳\n)\n***")).to eq([ "サンプル牛乳" ])
      end
    end

    context "品名として残すもの" do
      it "個数の書き方が入った品名は残す" do
        expect(item_lines("サンプル石鹸 2個パック\nサンプル石鹸 2個パック ¥398")).to eq([ "サンプル石鹸 2個パック", "サンプル石鹸 2個パック" ])
      end

      it "数字の入った品名は残す" do
        expect(item_lines("サンプル水 500ml\nサンプル紙 12ロール")).to eq([ "サンプル水 500ml", "サンプル紙 12ロール" ])
      end

      it "内で始まる品名は、内を外さない" do
        expect(item_lines("内祝サンプル菓子")).to eq([ "内祝サンプル菓子" ])
      end

      it "印のない数字で始まる品名は、数字を外さない" do
        expect(item_lines("12ロールサンプル紙")).to eq([ "12ロールサンプル紙" ])
      end
    end

    context "外す書き方" do
      it "行の頭の内税の印を外す" do
        expect(item_lines("内 サンプル牛乳\n内*サンプル洗剤")).to eq([ "サンプル牛乳", "サンプル洗剤" ])
      end

      it "行の頭の売り場の番号と印を外す" do
        expect(item_lines("03x サンプル牛乳\n11 ×サンプル洗剤\nA11 × サンプル石鹸\n01*サンプル水")).to eq([ "サンプル牛乳", "サンプル洗剤", "サンプル石鹸", "サンプル水" ])
      end

      it "行の末尾の金額を外す" do
        expect(item_lines("サンプル牛乳 ¥198\nサンプル洗剤 \\398")).to eq([ "サンプル牛乳", "サンプル洗剤" ])
      end

      it "外したあとに何も残らない行は除く" do
        expect(item_lines("サンプル牛乳\n内*")).to eq([ "サンプル牛乳" ])
      end
    end

    context "全体" do
      it "全角の空白を整え、空白だけの行は除く" do
        expect(item_lines("　サンプル　牛乳　\n　")).to eq([ "サンプル 牛乳" ])
      end

      it "同じ文字列の行は、レシートの順のまま残す" do
        expect(item_lines("サンプル牛乳\nサンプル洗剤\nサンプル牛乳")).to eq([ "サンプル牛乳", "サンプル洗剤", "サンプル牛乳" ])
      end

      it "品目の行がなければ、空の配列を返す" do
        expect(item_lines("2026年10月1日\n小計 ¥0")).to eq([])
      end

      it "全文が空なら、空の配列を返す" do
        expect(item_lines("")).to eq([])
      end

      it "レシートの全文から、品目行の候補を返す" do
        text = <<~TEXT
          サンプル商店
          TEL 000-000-0000
          2026年10月1日 (木) 12:00
          03x サンプル牛乳 ¥198
          1234567890128
          内*
          サンプル洗剤
          ¥398
          ¥100 2個
          サンプル石鹸 2個パック ¥200
          -\\20
          合計
          3点 小計 ¥776
          (内消費税 ¥70)
          お預り ¥1,000
        TEXT

        expect(item_lines(text)).to eq([ "サンプル牛乳", "サンプル洗剤", "サンプル石鹸 2個パック" ])
      end
    end
  end
end
