class ItemsController < ApplicationController
  before_action :set_item, only: %i[ show edit update ]

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

  def edit
    @form = ItemEditForm.from_item(@item)
  end

  def update
    @form = ItemEditForm.new(item_edit_form_params.merge(item: @item))
    if @form.save
      redirect_to item_path(@item), notice: update_message, status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    # ログイン中のユーザーの品目からだけ探す。ほかのユーザーの品目や、ない id は RecordNotFound になり、404 を返す
    def set_item
      @item = current_user.items.find(params.expect(:id))
    end

    # 品目は set_item で探したものを使うので、送られた値からは品目名・周期・画面に出していた周期だけを受け取る
    def item_edit_form_params
      params.expect(item_edit_form: [ :name, :cycle_days, :displayed_cycle_days ])
    end

    # 周期を変えたときは、これからの購入で補正し直すことも伝える
    def update_message
      @form.cycle_changed? ? t(".success_with_cycle_change") : t(".success")
    end

    # 残り日数の少ない順（目安を過ぎたものが上）。同じなら品目名の順。購入記録がない品目（残り日数が nil）は最後
    # sort_by は、並べる値が同じ要素の順を保たないので、品目名もキーに入れる
    def sort_key(estimate)
      [ estimate.days_left.nil? ? 1 : 0, estimate.days_left.to_i, estimate.item.name ]
    end
end
