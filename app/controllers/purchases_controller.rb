class PurchasesController < ApplicationController
  before_action :set_purchase, only: %i[ destroy ]

  # 消したあとは、その品目の詳細へ戻る（送ったページと同じ URL なので、Turbo は履歴を増やさずに描き直す）
  def destroy
    @purchase.destroy!
    redirect_to item_path(@item), notice: t(".success", date: l(@purchase.purchased_on)), status: :see_other
  end

  private
    # ログイン中のユーザーの品目から探し、その品目の購入記録から探す
    # ほかのユーザーの品目、ほかの品目の購入記録、ない id は RecordNotFound になり、404 を返す
    def set_purchase
      @item = current_user.items.find(params.expect(:item_id))
      @purchase = @item.purchases.find(params.expect(:id))
    end
end
