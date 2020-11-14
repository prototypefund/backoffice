defmodule DealogBackoffice.MessagesTest do
  use DealogBackoffice.DataCase

  alias DealogBackoffice.Messages

  alias DealogBackoffice.Messages.Projections.{
    Message,
    MessageForApproval,
    DeletedMessage,
    PublishedMessage
  }

  @valid_data %{title: "The title", body: "The body"}
  @invalid_data %{title: nil, body: nil}

  describe "create message" do
    @tag :integration
    test "should succeed with valid data" do
      assert {:ok, %Message{} = message} = Messages.create_message(@valid_data)
      assert message.title == @valid_data.title
      assert message.body == @valid_data.body
    end

    @tag :integration
    test "should fail with invalid data" do
      assert {:error, {:validation_failure, errors}} = Messages.create_message(@invalid_data)
      assert %{title: _, body: _} = errors
    end
  end

  describe "change message" do
    @valid_update_data %{title: "An updated title", body: "An updated body"}
    @invalid_update_data %{title: nil, body: nil}

    @tag :integration
    test "should succeed with valid data" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)
      {:ok, %Message{} = updated_message} = Messages.change_message(message, @valid_update_data)

      refute updated_message == message
      assert updated_message.title == @valid_update_data.title
      assert updated_message.body == @valid_update_data.body
    end

    @tag :integration
    test "should succeed but not change if input is same as original" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)
      {:ok, %Message{} = updated_message} = Messages.change_message(message, @valid_data)

      assert updated_message == message
    end

    @tag :integration
    test "should fail with invalid data" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)

      assert {:error, {:validation_failure, errors}} =
               Messages.change_message(message, @invalid_update_data)

      assert %{title: _, body: _} = errors
    end
  end

  describe "send message for approval" do
    @tag :integration
    test "should succeed if in status draft" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)

      assert {:ok, %Message{} = sent_message} = Messages.send_message_for_approval(message)
      assert message.status == :draft
      assert sent_message.status == :waiting_for_approval
    end

    @tag :integration
    test "should fail when not in draft" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)
      {:ok, %Message{} = sent_message} = Messages.send_message_for_approval(message)

      assert {:error, :invalid_transition} = Messages.send_message_for_approval(sent_message)
    end
  end

  describe "delete message" do
    @tag :integration
    test "should succeed if in status draft" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)

      assert message.status == :draft
      assert {:ok, %DeletedMessage{} = deleted_message} = Messages.delete_message(message.id)
      assert {:error, :not_found} = Messages.get_message(message.id)
      assert deleted_message.status == :deleted
    end

    @tag :integration
    test "should fail when not in draft" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)
      {:ok, %Message{} = sent_message} = Messages.send_message_for_approval(message)

      assert {:error, :invalid_transition} = Messages.delete_message(sent_message.id)
    end
  end

  describe "approve message" do
    @tag :integration
    test "should succeed without adding a note" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)
      Messages.send_message_for_approval(message)

      {:ok, %MessageForApproval{} = message_for_approval} =
        Messages.get_message_for_approval(message.id)

      assert message_for_approval.status == :waiting_for_approval

      assert {:ok, %MessageForApproval{} = approved_message} =
               Messages.approve_message(message_for_approval)

      assert approved_message.status == :approved
    end

    @tag :integration
    test "should succeed with a note attached" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)
      Messages.send_message_for_approval(message)

      {:ok, %MessageForApproval{} = message_for_approval} =
        Messages.get_message_for_approval(message.id)

      assert message_for_approval.status == :waiting_for_approval

      assert {:ok, %MessageForApproval{} = approved_message} =
               Messages.approve_message(message_for_approval, "A note")

      assert approved_message.status == :approved
      assert approved_message.note == "A note"
    end

    @tag :integration
    test "should fail when not in status waiting for approval" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)
      Messages.send_message_for_approval(message)

      {:ok, %MessageForApproval{} = message_for_approval} =
        Messages.get_message_for_approval(message.id)

      {:ok, %MessageForApproval{} = approved_message} =
        Messages.approve_message(message_for_approval)

      assert {:error, :invalid_transition} = Messages.approve_message(approved_message)
    end
  end

  describe "reject message" do
    @tag :integration
    test "should succeed without giving a reason" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)
      Messages.send_message_for_approval(message)

      {:ok, %MessageForApproval{} = message_for_approval} =
        Messages.get_message_for_approval(message.id)

      assert message_for_approval.status == :waiting_for_approval

      assert {:ok, %Message{} = rejected_message} = Messages.reject_message(message_for_approval)

      assert rejected_message.status == :rejected
    end

    @tag :integration
    test "should succeed with a reason attached" do
      {:ok, %Message{} = message} = Messages.create_message(@valid_data)
      Messages.send_message_for_approval(message)

      {:ok, %MessageForApproval{} = message_for_approval} =
        Messages.get_message_for_approval(message.id)

      assert message_for_approval.status == :waiting_for_approval

      assert {:ok, %Message{} = rejected_message} =
               Messages.reject_message(message_for_approval, "A reason")

      assert rejected_message.status == :rejected
      assert rejected_message.rejection_reason == "A reason"
    end
  end

  describe "publish message" do
    @tag :integration
    test "should succeed" do
      with {:ok, message} = Messages.create_message(@valid_data),
           {:ok, _} = Messages.send_message_for_approval(message),
           {:ok, message_for_approval} = Messages.get_message_for_approval(message.id),
           {:ok, approved_message} = Messages.approve_message(message_for_approval) do
        assert {:ok, %PublishedMessage{} = published_message} =
                 Messages.publish_message(approved_message)

        assert published_message.title == @valid_data.title
        assert published_message.body == @valid_data.body
        assert published_message.status == :published
      end
    end
  end
end