require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "GET /users/sign_in" do
    it "ログインしていなければ、ログイン画面を表示し、ヘッダーには新規登録のリンクだけを出す" do
      get new_user_session_path

      expect(response).to have_http_status(200)
      expect(response.body).to have_css("header a[href='#{new_user_registration_path}']")
      expect(response.body).not_to have_css("header a[href='#{new_user_session_path}']")
    end

    it "ログインしていれば、トップへ戻す" do
      sign_in create(:user)
      get new_user_session_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t("devise.failure.already_authenticated"))
    end
  end

  describe "POST /users/sign_in" do
    it "正しいメールアドレスとパスワードなら、ログインしてトップへ戻し、知らせを出す" do
      user = create(:user)
      post user_session_path, params: { user: { email: user.email, password: user.password } }

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq(I18n.t("devise.sessions.signed_in"))

      follow_redirect!
      expect(response.body).to include(I18n.t("devise.sessions.signed_in"))
    end

    it "保持にチェックしなければ、保持の Cookie を置かない" do
      user = create(:user)
      post user_session_path, params: { user: { email: user.email, password: user.password } }

      expect(cookies["remember_user_token"]).to be_blank
      expect(user.reload.remember_created_at).to be_nil
    end

    it "保持にチェックすると、保持の Cookie を置き、保持を始めた日時を保存する" do
      user = create(:user)
      post user_session_path, params: { user: { email: user.email, password: user.password, remember_me: "1" } }

      expect(cookies["remember_user_token"]).to be_present
      expect(user.reload.remember_created_at).to be_present
    end

    it "パスワードが違うと、422 でログイン画面を描き直し、ヘッダーには新規登録のリンクだけを出す" do
      user = create(:user)
      post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }

      expect(response).to have_http_status(422)
      expect(response.body).to include("メールアドレスまたはパスワードが違います。")
      expect(response.body).to have_css("header a[href='#{new_user_registration_path}']")
      expect(response.body).not_to have_css("header a[href='#{new_user_session_path}']")
    end

    it "登録のないメールアドレスでも、パスワードが違うときと同じ文で 422 を返す" do
      post user_session_path, params: { user: { email: "nobody@example.com", password: "password123" } }

      expect(response).to have_http_status(422)
      expect(response.body).to include("メールアドレスまたはパスワードが違います。")
    end
  end

  describe "DELETE /users/sign_out" do
    it "ログアウトしてトップへ戻し、そのあとのトップは未ログインの画面になる" do
      sign_in create(:user)
      delete destroy_user_session_path

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq(I18n.t("devise.sessions.signed_out"))

      get root_path
      expect(response.body).to include("レシートを撮るだけ。")
    end

    it "保持ありでログインしていたら、保持の Cookie と保持を始めた日時を消す" do
      user = create(:user)
      post user_session_path, params: { user: { email: user.email, password: user.password, remember_me: "1" } }
      delete destroy_user_session_path

      expect(cookies["remember_user_token"]).to be_blank
      expect(user.reload.remember_created_at).to be_nil
    end
  end

  describe "ログインが要るページ" do
    it "ログインしていなければ、ログイン画面へ送る" do
      get edit_user_registration_path

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq(I18n.t("devise.failure.unauthenticated"))
    end
  end
end
