class ItemsController < ApplicationController
  before_action :set_item, only: %i[ show ]

  def index
    @estimates = current_user.items.includes(:purchases)
      .map { |item| ConsumptionEstimate.new(item) }
      .sort_by { |estimate| sort_key(estimate) }
    # 上の2つの枠と、そのほか。select・reject は順を変えないので、どれも sort_key の順のまま
    @overdue_estimates = @estimates.select(&:overdue?)
    @running_low_estimates = @estimates.select(&:running_low?)
    @other_estimates = @estimates.reject { |estimate| estimate.overdue? || estimate.running_low? }
  end

  def show
    @estimate = ConsumptionEstimate.new(@item)
    # 購入日の新しい順。同じ日は、あとから登録したもの（id の大きいもの）を上にする
    @purchases = @item.purchases.order(purchased_on: :desc, id: :desc)
  end

  private
    # ログイン中のユーザーの品目からだけ探す。ほかのユーザーの品目や、ない id は RecordNotFound になり、404 を返す
    def set_item
      @item = current_user.items.find(params.expect(:id))
    end

    # 残り日数の少ない順（目安を過ぎたものが上）。同じなら品目名の順。購入記録がない品目（残り日数が nil）は最後
    # sort_by は、並べる値が同じ要素の順を保たないので、品目名もキーに入れる
    def sort_key(estimate)
      [ estimate.days_left.nil? ? 1 : 0, estimate.days_left.to_i, estimate.item.name ]
    end
end
