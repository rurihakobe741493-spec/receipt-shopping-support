# 品目の購入記録から、最終購入日・周期・次回購入目安・残り日数を計算する（計算結果は保存しない）
# 購入記録は item.purchases を map で読む。一覧で includes(:purchases) した記録をそのまま使うため、
# maximum・order・where などの SQL を出すメソッドは使わない
class ConsumptionEstimate
  # 残り日数がこの日数以下（0＝今日を含む）なら「そろそろ切れそう」
  RUNNING_LOW_DAYS = 7

  # 一覧で、推定と一緒に品目（品目名など）を読むため
  attr_reader :item

  def initialize(item)
    @item = item
    @today = Date.current
    # 同じ日の購入は1回とみなす
    @purchase_dates = item.purchases.map(&:purchased_on).uniq
  end

  def last_purchased_on
    @purchase_dates.max
  end

  # 計算に使う購入日が1日分以下なら品目の周期、2日分以上なら間隔の平均（四捨五入）
  def cycle_days
    dates = dates_for_cycle
    return @item.cycle_days if dates.size <= 1

    # 日付の差は分数（Rational）なので、割ってから丸める（先に整数にすると切り捨てになる）
    ((dates.max - dates.min) / (dates.size - 1)).round
  end

  def next_purchase_on
    return nil if last_purchased_on.nil?

    last_purchased_on + cycle_days
  end

  def days_left
    return nil if next_purchase_on.nil?

    # 日付の差は分数（Rational）なので、整数にする
    (next_purchase_on - @today).to_i
  end

  # 次回購入目安を過ぎた（残り日数がマイナス）。購入記録がない品目は false
  def overdue?
    !days_left.nil? && days_left.negative?
  end

  # 残り0〜RUNNING_LOW_DAYS日。購入記録がない品目は false
  def running_low?
    !days_left.nil? && days_left.between?(0, RUNNING_LOW_DAYS)
  end

  private

  # 周期を変えていれば、変えた日（当日を含む）以降の購入日だけを使う
  def dates_for_cycle
    return @purchase_dates if @item.cycle_changed_on.nil?

    @purchase_dates.select { |date| date >= @item.cycle_changed_on }
  end
end
