class ItemsController < ApplicationController
  before_action :set_item, only: %i[ show edit update destroy ]

  def index
    @stock_list = StockList.new(current_user.items)
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

  # 消したあとはトップへ戻る。購入記録は、モデルの dependent: :destroy で一緒に消える
  def destroy
    @item.destroy!
    redirect_to root_path, notice: t(".success", name: @item.name), status: :see_other
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
end
