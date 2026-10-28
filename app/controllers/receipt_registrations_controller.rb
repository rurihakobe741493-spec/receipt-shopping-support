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
end
