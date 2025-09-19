# app/controllers/mapping_profiles_controller.rb
class MappingProfilesController < ApplicationController
  def edit
    @profile = MappingProfile.first_or_create!(name: "Default")
  end

  def update
    @profile = MappingProfile.first
    if @profile.update(profile_params)
      redirect_to edit_mapping_profile_path, notice: "Mapping updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:mapping_profile).permit(:name, :revenue_gl, :refunds_gl, :chargebacks_gl, :fees_gl, :payout_fees_gl, :cash_account_gl, :clearing_account_gl, :settings)
  end
end
