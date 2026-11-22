# ログイン・ログアウト。Devise のコントローラーを受け継ぎ、ゲストでログインする操作を足す
class Users::SessionsController < Devise::SessionsController
  # ゲストを作る回数（IP ごと）。作り直して読み取りの回数を戻すことと、DB の行が増えることを抑える
  GUEST_SIGN_INS_PER_HOUR = 10

  # ログイン中なら、ゲストを作らずに戻す（Devise の new・create と同じ扱い）。
  # Symbol で足すと、Devise の同じ名前のフィルター（only: [:new, :create]）を置き換えてしまうので、ブロックで足す
  prepend_before_action(only: :guest_sign_in) { require_no_authentication }
  rate_limit to: GUEST_SIGN_INS_PER_HOUR, within: 1.hour, name: "guest_sign_in",
             with: -> { redirect_to root_path, alert: t(".too_many"), status: :see_other },
             only: :guest_sign_in

  def guest_sign_in
    sign_in(GuestUserCreator.call)
    redirect_to root_path, notice: t(".signed_in"), status: :see_other
  end

  # ゲストがログアウトしたら、そのゲストを品目ごと消す（ログアウトすると、二度とそのゲストに入れないため）
  # Devise の destroy は、ログアウトして知らせを入れたあと、応答の前にブロックを呼ぶ
  def destroy
    # 品目ごとに購入記録を1回ずつ読まないよう、まとめて読んでから消す（N+1 を避ける）
    guest = User.includes(items: :purchases).find(current_user.id) if current_user&.guest?
    super do
      guest&.destroy
    end
  end
end
