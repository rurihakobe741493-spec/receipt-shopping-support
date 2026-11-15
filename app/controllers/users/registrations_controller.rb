# ゲストには、アカウント設定（メールアドレス・パスワードの変更と退会）を使わせない
# Devise の authenticate_scope!（prepend_before_action）のあとに動くので、current_user はいる
class Users::RegistrationsController < Devise::RegistrationsController
  before_action :reject_guest, only: [ :edit, :update, :destroy ]

  private

    def reject_guest
      return unless current_user.guest?

      # 訳は users.registrations.guest_not_allowed（アクションの名前を挟まない段にも探しに行く）
      redirect_to root_path, alert: t(".guest_not_allowed"), status: :see_other
    end
end
