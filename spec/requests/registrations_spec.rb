require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /users/sign_up" do
    it "新規登録の画面を表示し、ヘッダーにはログインのリンクだけを出す" do
      get new_user_registration_path

      expect(response).to have_http_status(200)
      expect(response.body).to have_field("user[email]")
      expect(response.body).to have_field("user[password]")
      expect(response.body).to have_field("user[password_confirmation]")
      expect(response.body).to have_css("header a[href='#{new_user_session_path}']")
      expect(response.body).not_to have_css("header a[href='#{new_user_registration_path}']")
    end
  end

  describe "POST /users" do
    it "正しく入力すると、ユーザーを作り、ログインした状態でトップへ戻す" do
      expect { post user_registration_path, params: { user: attributes_for(:user) } }.to change(User, :count).by(1)

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq(I18n.t("devise.registrations.signed_up"))

      follow_redirect!
      expect(response.body).to have_css("form[action='#{receipt_scans_path}']")
    end

    it "メールアドレスが空なら、422 で描き直し、ヘッダーには新規登録のリンクを出さない" do
      expect { post user_registration_path, params: { user: attributes_for(:user, email: "") } }.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect(response.body).to include("メールアドレスを入力してください")
      expect(response.body).not_to have_css("header a[href='#{new_user_registration_path}']")
    end

    it "パスワードが7文字なら、422 で描き直す" do
      expect { post user_registration_path, params: { user: attributes_for(:user, password: "a" * 7) } }.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect(response.body).to include("パスワードは8文字以上で入力してください")
    end

    it "確認のパスワードが一致しないなら、422 で描き直す" do
      expect { post user_registration_path, params: { user: attributes_for(:user, password_confirmation: "different123") } }.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect(response.body).to include("パスワード（確認）とパスワードの入力が一致しません")
    end

    it "登録済みのメールアドレス（大文字違い）なら、422 で描き直す" do
      create(:user, email: "taken@example.com")

      expect { post user_registration_path, params: { user: attributes_for(:user, email: "TAKEN@example.com") } }.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect(response.body).to include("メールアドレスはすでに存在します")
    end
  end
end
