# ストック一覧（ログイン後のトップ）の推定を、残り日数の少ない順に並べ、2つの枠とそのほかに分ける
# 品目ごとに推定を1回だけ作るので、並べ方と振り分けで同じ今日を使う
class StockList
  def initialize(items)
    # 購入記録を先読みする（推定は item.purchases を map で読むので、品目ごとの SQL は出ない）
    @estimates = items.includes(:purchases)
      .map { |item| ConsumptionEstimate.new(item) }
      .sort_by { |estimate| sort_key(estimate) }
  end

  def empty?
    @estimates.empty?
  end

  # 並べた順のすべて（トップでは、この順のまま1つの一覧に並べる）
  def all
    @estimates
  end

  # 下の3つは、どれも並べた順のまま（select・reject は順を変えない）
  # ビューが何度か呼ぶので、1回目の結果を覚えておく
  def overdue
    @overdue ||= @estimates.select(&:overdue?)
  end

  def running_low
    @running_low ||= @estimates.select(&:running_low?)
  end

  # 上の2つの枠に出した品目は外す（同じ品目が、枠のすぐ下の一覧にもう一度並ばないように）
  def others
    @others ||= @estimates.reject { |estimate| estimate.overdue? || estimate.running_low? }
  end

  private

    # 残り日数の少ない順（目安を過ぎたものが上）。同じなら品目名の順。購入記録がない品目（残り日数が nil）は最後
    # sort_by は、並べる値が同じ要素の順を保たないので、品目名もキーに入れる
    def sort_key(estimate)
      [ estimate.days_left.nil? ? 1 : 0, estimate.days_left.to_i, estimate.item.name ]
    end
end
