# frozen_string_literal: true

class BackfillActivities < ActiveRecord::Migration[7.1]
  def up
    Model.unscoped.limit(20).order(created_at: :desc).each do |model|
      model.send :post_creation_activity if model.actor.activities.empty? rescue nil
    end
  end

  def down
  end
end
