ActiveAdmin.register Place do
  permit_params :name, :address, :latitude, :longitude

  controller do
    def find_resource
      scoped_collection.find_by!(public_uid: params[:id])
    end
  end
end
