ActiveAdmin.register Event do
  permit_params :title, :held_on, :url, :place_id

  controller do
    def find_resource
      scoped_collection.find_by!(public_uid: params[:id])
    end
  end
end
