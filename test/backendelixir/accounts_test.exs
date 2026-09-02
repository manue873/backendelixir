defmodule Backendelixir.AccountsTest do
  use Backendelixir.DataCase

  alias Backendelixir.Accounts
  alias Backendelixir.Accounts.User

  describe "users and authentication" do
    @valid_user_attrs %{
      email: "test.driver@piura.pe",
      name: "Chofer Test",
      password: "Password123!",
      role: "CONDUCTOR"
    }

    test "register_user/1 with valid data creates a user with hashed password" do
      assert {:ok, %User{} = user} = Accounts.register_user(@valid_user_attrs)
      assert user.email == "test.driver@piura.pe"
      assert user.name == "Chofer Test"
      assert user.role == "CONDUCTOR"
      assert user.password_hash != nil
      assert user.password_hash != "Password123!"
    end

    test "register_user/1 enforces unique email constraint" do
      {:ok, _user} = Accounts.register_user(@valid_user_attrs)
      assert {:error, changeset} = Accounts.register_user(@valid_user_attrs)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "register_user/1 validates password length" do
      invalid_attrs = Map.put(@valid_user_attrs, :password, "123")
      assert {:error, changeset} = Accounts.register_user(invalid_attrs)
      assert %{password: [_]} = errors_on(changeset)
    end

    test "authenticate_by_email_and_password/2 with valid credentials returns user" do
      {:ok, user} = Accounts.register_user(@valid_user_attrs)

      assert {:ok, authenticated_user} =
               Accounts.authenticate_by_email_and_password("test.driver@piura.pe", "Password123!")

      assert authenticated_user.id == user.id
    end

    test "authenticate_by_email_and_password/2 with invalid password returns error" do
      {:ok, _user} = Accounts.register_user(@valid_user_attrs)

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_by_email_and_password(
                 "test.driver@piura.pe",
                 "WrongPassword"
               )
    end

    test "authenticate_by_email_and_password/2 with non-existing user returns error" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_by_email_and_password("noone@piura.pe", "Password123!")
    end

    test "generate_user_token/1 and verify_user_token/1 successfully sign and verify token" do
      {:ok, user} = Accounts.register_user(@valid_user_attrs)
      token = Accounts.generate_user_token(user)
      assert is_binary(token)

      assert {:ok, verified_user, payload} = Accounts.verify_user_token(token)
      assert verified_user.id == user.id
      assert payload.email == "test.driver@piura.pe"
      assert payload.role == "CONDUCTOR"
    end

    test "verify_user_token/1 with invalid token returns error" do
      assert {:error, :invalid} = Accounts.verify_user_token("invalid_token_string")
    end
  end
end
