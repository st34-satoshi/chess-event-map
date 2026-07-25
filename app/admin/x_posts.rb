ActiveAdmin.register XPost do
  actions :index, :show

  includes :x_account

  index do
    selectable_column
    id_column
    column :x_account do |post|
      auto_link post.x_account, "@#{post.x_account.at_name}"
    end
    column :text do |post|
      truncate(post.text, length: 80)
    end
    column :event_detection_status
    column :posted_at
    column :url do |post|
      if post.url.present?
        link_to "X", post.url, target: "_blank", rel: "noopener"
      end
    end
    actions
  end

  show do
    attributes_table do
      row :public_uid
      row :x_account do |post|
        auto_link post.x_account, "@#{post.x_account.at_name}"
      end
      row :x_post_id
      row :text do |post|
        simple_format post.text
      end
      row :event_detection_status
      row :posted_at
      row :url do |post|
        if post.url.present?
          link_to post.url, post.url, target: "_blank", rel: "noopener"
        end
      end
      row :created_at
      row :updated_at
    end
  end

  filter :x_account, collection: -> { XAccount.order(:at_name) }
  filter :event_detection_status, as: :select, collection: XPost.event_detection_statuses.keys
  filter :text
  filter :posted_at
  filter :created_at

  controller do
    def find_resource
      scoped_collection.find_by!(public_uid: params[:id])
    end
  end
end
