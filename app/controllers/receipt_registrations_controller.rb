class ReceiptRegistrationsController < ApplicationController
  def create
    @form = ReceiptRegistrationForm.new(receipt_registration_form_params.merge(user: current_user))

    if @form.save
      redirect_to root_path, notice: t(".success", count: @form.purchases_count), status: :see_other
    else
      render :create, status: :unprocessable_content
    end
  end

  private

    def receipt_registration_form_params
      params.expect(receipt_registration_form: [ :purchased_on, rows_attributes: [ [ :selected, :receipt_name, :item_id ] ] ])
    end

    # 新しく作った品目があるときだけ、その数も伝える
    def success_message
      if @form.new_items_count.positive?
        t(".success_with_new_items", new_items_count: @form.new_items_count, count: @form.purchases_count)
      else
        t(".success", count: @form.purchases_count)
      end
    end
end
